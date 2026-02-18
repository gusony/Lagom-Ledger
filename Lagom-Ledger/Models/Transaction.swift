//
//  Transaction.swift
//  Lagom Ledger
//
//  交易記錄模型
//

import Foundation

// MARK: - 交易類型
enum TransactionType: String, Codable, CaseIterable {
    case expense = "支出"
    case income = "收入"
}

// MARK: - 支出類別
enum ExpenseCategory: String, Codable, CaseIterable {
    case food = "飲食"
    case transport = "交通"
    case entertainment = "娛樂"
    case shopping = "購物"
    case housing = "住房"
    case medical = "醫療"
    case education = "教育"
    case other = "其他"
}

// MARK: - 收入類別
enum IncomeCategory: String, Codable, CaseIterable {
    case salary = "薪資"
    case dividend = "股票股息"
    case capitalGain = "價差"
    case bonus = "獎金"
    case lottery = "抽獎"
    case freelance = "兼職"
    case other = "其他"
}

// MARK: - 交易記錄
struct Transaction: Identifiable, Codable, Equatable {
    var id: UUID
    var type: TransactionType
    var category: String  // 儲存 rawValue
    var amount: Double
    var name: String?
    var imageData: Data?
    var date: Date
    
    init(
        id: UUID = UUID(),
        type: TransactionType,
        category: String,
        amount: Double,
        name: String? = nil,
        imageData: Data? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.amount = amount
        self.name = name
        self.imageData = imageData
        self.date = date
    }
    
    var categoryDisplayName: String { category }
    var amountDisplay: String { String(format: "%.0f", amount) }
}
