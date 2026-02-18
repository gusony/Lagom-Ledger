//
//  InvoiceQRParser.swift
//  Lagom Ledger
//
//  電子發票證明聯二維條碼解析
//  依財政部「電子發票證明聯一維及二維條碼法規格說明」格式
//
//  電子發票證明聯有兩個 QR Code（左右並列）：
//  - 左方：基本資訊（發票字軌、金額、日期）+ 部分品名
//  - 右方：以 ** 開頭，接續品名等延伸資訊
//  程式會自動辨識並合併兩者，使用者無需區分左右
//

import Foundation

/// 解析電子發票 QR Code 後的結果
struct InvoiceQRResult {
    /// 發票字軌號碼（10 碼）
    let invoiceNumber: String
    /// 含稅總金額
    let totalAmount: Double
    /// 店家名稱或首個品名
    let storeName: String?
    /// 發票開立日期
    let invoiceDate: Date?
}

/// 掃描到的條碼類型
enum InvoiceQRType {
    case left(content: String)   // 左方條碼
    case right(content: String)  // 右方條碼（** 開頭）
}

enum InvoiceQRParser {
    
    /// 判斷條碼為左方或右方
    static func detectType(_ qrString: String) -> InvoiceQRType? {
        let trimmed = qrString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("**") {
            return .right(content: trimmed)
        }
        if parseLeftQR(trimmed) != nil {
            return .left(content: trimmed)
        }
        return nil
    }
    
    /// 解析左方條碼（基本資訊）
    static func parseLeftQR(_ qrString: String) -> InvoiceQRResult? {
        let trimmed = qrString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 37 else { return nil }
        guard !trimmed.hasPrefix("**") else { return nil }
        
        let invoiceNumber = String(trimmed.prefix(10))
        guard invoiceNumber.count == 10 else { return nil }
        
        let totalAmountStart = trimmed.index(trimmed.startIndex, offsetBy: 29)
        let totalAmountEnd = trimmed.index(trimmed.startIndex, offsetBy: 37)
        guard totalAmountEnd <= trimmed.endIndex else { return nil }
        
        let totalAmountHex = String(trimmed[totalAmountStart..<totalAmountEnd])
        let totalAmount = Double(Int(totalAmountHex, radix: 16) ?? 0)
        guard totalAmount > 0 else { return nil }
        
        var invoiceDate: Date? = nil
        if trimmed.count >= 17 {
            let dateStr = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 10)..<trimmed.index(trimmed.startIndex, offsetBy: 17)])
            if let rocYear = Int(dateStr.prefix(3)),
               let month = Int(dateStr.dropFirst(3).prefix(2)),
               let day = Int(dateStr.suffix(2)) {
                var components = DateComponents()
                components.year = rocYear + 1911
                components.month = month
                components.day = day
                components.hour = 12
                components.minute = 0
                components.second = 0
                invoiceDate = Calendar.current.date(from: components)
            }
        }
        
        let storeName = extractStoreName(from: trimmed, startOffset: 77)
        
        return InvoiceQRResult(
            invoiceNumber: invoiceNumber,
            totalAmount: totalAmount,
            storeName: storeName,
            invoiceDate: invoiceDate
        )
    }
    
    /// 解析右方條碼（** 開頭），擷取品名
    static func parseRightQR(_ qrString: String) -> String? {
        let trimmed = qrString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("**") else { return nil }
        let afterMarker = String(trimmed.dropFirst(2))
        return extractStoreName(from: afterMarker, startOffset: 0)
    }
    
    /// 從字串中擷取有效品名（以冒號分隔，取第一個非空且非遮蔽的有效欄位）
    private static func extractStoreName(from string: String, startOffset: Int) -> String? {
        guard string.count > startOffset else { return nil }
        let start = string.index(string.startIndex, offsetBy: min(startOffset, string.count))
        let content = String(string[start...])
        let parts = content.split(separator: ":", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        for part in parts where !part.isEmpty {
            if isValidStoreName(part) {
                return part
            }
        }
        return nil
    }
    
    /// 過濾無效品名（****、純符號等）
    private static func isValidStoreName(_ name: String) -> Bool {
        let t = name.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return false }
        // 排除只含 * 或類似遮蔽符的內容
        let withoutStars = t.replacingOccurrences(of: "*", with: "")
        guard !withoutStars.isEmpty else { return false }
        // 排除過短或純數字（可能是數量/單價）
        guard t.count >= 2 else { return false }
        return true
    }
    
    /// 合併左方結果與右方品名（右方品名優先，因左方可能為 ****）
    static func merge(left: InvoiceQRResult, rightStoreName: String?) -> InvoiceQRResult {
        let finalStoreName: String?
        if let right = rightStoreName, isValidStoreName(right) {
            finalStoreName = right
        } else if let leftName = left.storeName, isValidStoreName(leftName) {
            finalStoreName = leftName
        } else {
            finalStoreName = nil
        }
        return InvoiceQRResult(
            invoiceNumber: left.invoiceNumber,
            totalAmount: left.totalAmount,
            storeName: finalStoreName,
            invoiceDate: left.invoiceDate
        )
    }
}
