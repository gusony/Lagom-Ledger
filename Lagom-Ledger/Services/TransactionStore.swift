//
//  TransactionStore.swift
//  Lagom Ledger
//
//  交易資料儲存與讀取
//

import Foundation
import SwiftUI

@MainActor
class TransactionStore: ObservableObject {
    static let shared = TransactionStore()
    
    @Published var transactions: [Transaction] = []
    
    private let fileURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("transactions.json")
    }()
    
    private init() {
        load()
        if transactions.isEmpty {
            addSampleData()
        }
    }
    
    private func addSampleData() {
        let calendar = Calendar.current
        let now = Date()
        let defaultLedgerId = LedgerStore.shared.ledgers.first?.id
        
        let samples: [Transaction] = [
            Transaction(type: .expense, category: ExpenseCategory.food.rawValue, amount: 120, name: "午餐", date: now, ledgerId: defaultLedgerId),
            Transaction(type: .expense, category: ExpenseCategory.transport.rawValue, amount: 50, name: "捷運", date: calendar.date(byAdding: .day, value: -1, to: now)!, ledgerId: defaultLedgerId),
            Transaction(type: .income, category: IncomeCategory.salary.rawValue, amount: 50000, name: "月薪", date: calendar.date(byAdding: .day, value: -5, to: now)!, ledgerId: defaultLedgerId),
            Transaction(type: .expense, category: ExpenseCategory.shopping.rawValue, amount: 350, name: "日用品", date: calendar.date(byAdding: .day, value: -3, to: now)!, ledgerId: defaultLedgerId),
        ]
        
        for t in samples {
            transactions.append(t)
        }
        transactions.sort { $0.date > $1.date }
        save()
    }
    
    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            transactions = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            var decoded = try JSONDecoder().decode([Transaction].self, from: data)
            // 舊資料遷移：無 ledgerId 的歸入預設記帳本
            if let defaultLedgerId = LedgerStore.shared.ledgers.first?.id {
                for i in decoded.indices where decoded[i].ledgerId == nil {
                    decoded[i].ledgerId = defaultLedgerId
                }
            }
            transactions = decoded.sorted { $0.date > $1.date }
            applyRetentionLimit()
            save()
        } catch {
            print("載入失敗: \(error)")
            transactions = []
        }
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(transactions)
            try data.write(to: fileURL)
            Task { @MainActor in
                if SettingsStore.shared.iCloudBackupEnabled {
                    backupToiCloud()
                }
            }
        } catch {
            print("儲存失敗: \(error)")
        }
    }
    
    private func backupToiCloud() {
        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return }
        let iCloudBackupURL = iCloudURL.appendingPathComponent("Documents/transactions.json")
        do {
            try FileManager.default.createDirectory(
                at: iCloudBackupURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: iCloudBackupURL.path) {
                try FileManager.default.removeItem(at: iCloudBackupURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: iCloudBackupURL)
        } catch {
            print("iCloud 備份失敗: \(error)")
        }
    }
    
    func add(_ transaction: Transaction) {
        transactions.insert(transaction, at: 0)
        transactions.sort { $0.date > $1.date }
        save()
    }
    
    func delete(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        save()
    }
    
    func update(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
            transactions.sort { $0.date > $1.date }
            save()
        }
    }
    
    // MARK: - 篩選（ledgerId: nil = 全部）
    
    private func filtered(by ledgerId: UUID?) -> [Transaction] {
        guard let id = ledgerId else { return transactions }
        return transactions.filter { $0.ledgerId == id }
    }
    
    func transactions(for year: Int, ledgerId: UUID? = nil) -> [Transaction] {
        filtered(by: ledgerId).filter { Calendar.current.component(.year, from: $0.date) == year }
    }
    
    func transactions(for year: Int, month: Int, ledgerId: UUID? = nil) -> [Transaction] {
        filtered(by: ledgerId).filter {
            Calendar.current.component(.year, from: $0.date) == year &&
            Calendar.current.component(.month, from: $0.date) == month
        }
    }
    
    func transactions(for date: Date, ledgerId: UUID? = nil) -> [Transaction] {
        filtered(by: ledgerId).filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    // MARK: - 搜尋
    
    func search(startDate: Date?, endDate: Date?, name: String, ledgerId: UUID? = nil) -> [Transaction] {
        var result = filtered(by: ledgerId)
        
        if let start = startDate {
            result = result.filter { $0.date >= Calendar.current.startOfDay(for: start) }
        }
        if let end = endDate {
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
            result = result.filter { $0.date <= endOfDay }
        }
        
        let query = name.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            result = result.filter {
                ($0.name?.lowercased().contains(query) ?? false) ||
                $0.category.lowercased().contains(query) ||
                ($0.invoiceNumber?.lowercased().contains(query) ?? false)
            }
        }
        
        return result.sorted { $0.date > $1.date }
    }
    
    // MARK: - 報表
    
    /// 每月支出總額（用於走勢圖）
    func monthlyExpenseTotals(months: Int = 12, ledgerId: UUID? = nil) -> [(year: Int, month: Int, amount: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [(year: Int, month: Int, amount: Double)] = []
        
        for i in 0..<months {
            guard let date = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let monthTransactions = transactions(for: year, month: month, ledgerId: ledgerId)
            let total = monthTransactions
                .filter { $0.type == .expense }
                .reduce(0) { $0 + $1.amount }
            result.append((year, month, total))
        }
        return result.reversed()
    }
    
    /// 指定月份各類別支出比例
    func expenseByCategory(year: Int, month: Int, ledgerId: UUID? = nil) -> [(category: String, amount: Double)] {
        let monthTransactions = transactions(for: year, month: month, ledgerId: ledgerId)
            .filter { $0.type == .expense }
        
        var dict: [String: Double] = [:]
        for t in monthTransactions {
            dict[t.category, default: 0] += t.amount
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }
    
    // MARK: - 資料管理
    
    func clearAll() {
        transactions = []
        save()
    }
    
    /// 刪除指定記帳本的所有交易
    func deleteTransactions(ledgerId: UUID) {
        transactions.removeAll { $0.ledgerId == ledgerId }
        save()
    }
    
    /// 取得指定記帳本的所有交易（供匯出）
    func transactions(ledgerId: UUID) -> [Transaction] {
        transactions.filter { $0.ledgerId == ledgerId }
    }
    
    /// 套用資料保留限制，刪除超過 N 個月的舊資料
    func applyRetentionLimit() {
        let months = SettingsStore.shared.dataRetentionMonths
        guard months > 0 else { return }
        
        let cutoff = Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
        let before = transactions.count
        transactions = transactions.filter { $0.date >= cutoff }
        transactions.sort { $0.date > $1.date }
        if transactions.count < before {
            save()
        }
    }
    
    func importFromCSV(_ transactionsToAdd: [Transaction]) {
        for t in transactionsToAdd {
            var newT = t
            newT.id = UUID()
            transactions.append(newT)
        }
        transactions.sort { $0.date > $1.date }
        save()
    }
    
    func restoreFromiCloud() -> Bool {
        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return false }
        let iCloudBackupURL = iCloudURL.appendingPathComponent("Documents/transactions.json")
        
        guard FileManager.default.fileExists(atPath: iCloudBackupURL.path) else { return false }
        
        do {
            let data = try Data(contentsOf: iCloudBackupURL)
            let decoded = try JSONDecoder().decode([Transaction].self, from: data)
            transactions = decoded.sorted { $0.date > $1.date }
            try data.write(to: fileURL)
            return true
        } catch {
            print("iCloud 還原失敗: \(error)")
            return false
        }
    }
}
