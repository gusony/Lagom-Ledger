//
//  LotteryService.swift
//  Lagom Ledger
//
//  統一發票對獎：從財政部取得中獎號碼
//

import Foundation

/// 單一期別的中獎號碼
struct LotteryNumbers: Equatable {
    let period: String  // 如 "11409"
    let periodDisplay: String  // 如 "114年09-10月"
    let specialPrize: String  // 特別獎 8碼
    let grandPrize: String  // 特獎 8碼
    let firstPrizes: [String]  // 頭獎 3組
    let addSixPrizes: [String]  // 增開六獎 3碼
}

/// 對獎結果
struct LotteryWin: Equatable {
    let transaction: Transaction
    let prizeLevel: String
    let amount: Int
    let period: String
}

enum LotteryService {
    private static let baseURL = "https://www.etax.nat.gov.tw/etw-main/ETW183W2_"
    
    /// 取得指定期別的中獎號碼（民國年+奇數月，如 11409）
    static func fetchNumbers(period: String) async throws -> LotteryNumbers? {
        let urlStr = baseURL + period + "/"
        guard let url = URL(string: urlStr) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else { return nil }
        
        return parseLotteryHTML(html, period: period)
    }
    
    /// 解析 HTML 取得中獎號碼
    private static func parseLotteryHTML(_ html: String, period: String) -> LotteryNumbers? {
        // 8位數字：特別獎、特獎、頭獎
        let eightDigits = matches(of: #"\d{8}"#, in: html)
        var unique: [String] = []
        for d in eightDigits {
            if !unique.contains(d) { unique.append(d) }
        }
        
        guard unique.count >= 5 else { return nil }  // 特別獎1+特獎1+頭獎3
        
        let specialPrize = unique[0]
        let grandPrize = unique[1]
        let firstPrizes = Array(unique[2..<5])
        
        // 增開六獎：3碼（在「增開」關鍵字附近）
        var addSix: [String] = []
        if let range = html.range(of: "增開"),
           let suffix = html.suffix(from: range.upperBound).description as String? {
            let threeDigits = matches(of: #"\d{3}"#, in: suffix)
            addSix = Array(threeDigits.prefix(3))
        }
        
        let rocYear = Int(period.prefix(3)) ?? 0
        let month = Int(period.suffix(2)) ?? 0
        let nextMonth = month == 11 ? 12 : month + 1
        let periodDisplay = "\(rocYear)年\(String(format: "%02d", month))-\(String(format: "%02d", nextMonth))月"
        
        return LotteryNumbers(
            period: period,
            periodDisplay: periodDisplay,
            specialPrize: specialPrize,
            grandPrize: grandPrize,
            firstPrizes: firstPrizes,
            addSixPrizes: addSix
        )
    }
    
    private static func matches(of pattern: String, in string: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(string.startIndex..., in: string)
        let results = regex.matches(in: string, range: range)
        return results.compactMap { result in
            guard let r = Range(result.range, in: string) else { return nil }
            return String(string[r])
        }
    }
    
    /// 取得最近三期期別（1,3,5,7,9,11 月 25 日開獎）
    static func lastThreePeriods(referenceDate: Date = Date()) -> [String] {
        let cal = Calendar.current
        let year = cal.component(.year, from: referenceDate)
        let month = cal.component(.month, from: referenceDate)
        let day = cal.component(.day, from: referenceDate)
        
        var rocYear = year - 1911
        let oddMonths = [1, 3, 5, 7, 9, 11]
        
        var currentOddMonth = 1
        for m in oddMonths.reversed() {
            if month >= m {
                currentOddMonth = m
                break
            }
        }
        // 若 25 日之前，最新期尚未開獎，改用上一期
        if day < 25 {
            if let idx = oddMonths.firstIndex(of: currentOddMonth) {
                if idx > 0 {
                    currentOddMonth = oddMonths[idx - 1]
                } else {
                    currentOddMonth = 11
                    rocYear -= 1
                }
            }
        }
        
        var periods: [String] = []
        var y = rocYear
        var m = currentOddMonth
        for _ in 0..<3 {
            periods.append(String(format: "%03d%02d", y, m))
            if m == 1 {
                m = 11
                y -= 1
            } else {
                m -= 2
            }
        }
        return periods
    }
}
