//
//  LotteryChecker.swift
//  Lagom Ledger
//
//  統一發票對獎邏輯
//

import Foundation
import SwiftUI

/// 對獎結果摘要
struct LotteryResultSummary {
    let wins: [LotteryWin]
    let totalAmount: Int
    let byPeriod: [String: (count: Int, amount: Int)]
}

@MainActor
class LotteryChecker: ObservableObject {
    static let shared = LotteryChecker()
    
    private let lastCheckKey = "LotteryLastCheckPeriod"
    
    private init() {}
    
    /// 從發票字軌取得後8碼（對獎用）
    private func invoiceDigits8(_ invoiceNumber: String?) -> String? {
        guard let s = invoiceNumber?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        let digits = s.filter { $0.isNumber }
        guard digits.count >= 8 else { return nil }
        return String(digits.suffix(8))
    }
    
    /// 交易日期對應的期別（民國年+奇數月）
    private func periodFor(date: Date) -> String {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let rocYear = year - 1911
        let oddMonth: Int
        switch month {
        case 1...2: oddMonth = 1
        case 3...4: oddMonth = 3
        case 5...6: oddMonth = 5
        case 7...8: oddMonth = 7
        case 9...10: oddMonth = 9
        default: oddMonth = 11
        }
        return String(format: "%03d%02d", rocYear, oddMonth)
    }
    
    /// 單一發票對獎
    private func checkInvoice(_ digits: String, numbers: LotteryNumbers) -> (level: String, amount: Int)? {
        // 特別獎
        if digits == numbers.specialPrize { return ("特別獎", 10_000_000) }
        // 特獎
        if digits == numbers.grandPrize { return ("特獎", 2_000_000) }
        // 頭獎
        for p in numbers.firstPrizes {
            if digits == p { return ("頭獎", 200_000) }
        }
        // 二獎～六獎（比對頭獎末7～末3碼）
        for p in numbers.firstPrizes {
            if String(digits.suffix(7)) == String(p.suffix(7)) { return ("二獎", 40_000) }
            if String(digits.suffix(6)) == String(p.suffix(6)) { return ("三獎", 10_000) }
            if String(digits.suffix(5)) == String(p.suffix(5)) { return ("四獎", 4_000) }
            if String(digits.suffix(4)) == String(p.suffix(4)) { return ("五獎", 1_000) }
            if String(digits.suffix(3)) == String(p.suffix(3)) { return ("六獎", 200) }
        }
        // 增開六獎
        for p in numbers.addSixPrizes {
            if String(digits.suffix(3)) == p { return ("增開六獎", 200) }
        }
        return nil
    }
    
    /// 執行對獎
    func runCheck(transactions: [Transaction]) async -> LotteryResultSummary? {
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let toCheck = transactions
            .filter { $0.date >= sixMonthsAgo }
            .filter { invoiceDigits8($0.invoiceNumber) != nil }
        
        guard !toCheck.isEmpty else { return LotteryResultSummary(wins: [], totalAmount: 0, byPeriod: [:]) }
        
        let periods = LotteryService.lastThreePeriods()
        var allNumbers: [String: LotteryNumbers] = [:]
        
        for period in periods {
            if let nums = try? await LotteryService.fetchNumbers(period: period) {
                allNumbers[period] = nums
            }
        }
        
        var wins: [LotteryWin] = []
        
        for t in toCheck {
            guard let digits = invoiceDigits8(t.invoiceNumber) else { continue }
            let period = periodFor(date: t.date)
            guard let numbers = allNumbers[period] else { continue }
            
            if let (level, amount) = checkInvoice(digits, numbers: numbers) {
                wins.append(LotteryWin(
                    transaction: t,
                    prizeLevel: level,
                    amount: amount,
                    period: numbers.periodDisplay
                ))
            }
        }
        
        var byPeriod: [String: (count: Int, amount: Int)] = [:]
        for w in wins {
            let cur = byPeriod[w.period] ?? (0, 0)
            byPeriod[w.period] = (cur.0 + 1, cur.1 + w.amount)
        }
        
        let total = wins.reduce(0) { $0 + $1.amount }
        return LotteryResultSummary(wins: wins, totalAmount: total, byPeriod: byPeriod)
    }
    
    /// 最近一期是否已開獎且尚未對獎
    func needsCheckOnLaunch() -> Bool {
        let periods = LotteryService.lastThreePeriods()
        guard let latest = periods.first else { return false }
        let lastChecked = UserDefaults.standard.string(forKey: lastCheckKey)
        return lastChecked != latest
    }
    
    /// 標記已對獎
    func markChecked() {
        let periods = LotteryService.lastThreePeriods()
        if let latest = periods.first {
            UserDefaults.standard.set(latest, forKey: lastCheckKey)
        }
    }
}
