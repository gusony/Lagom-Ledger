//
//  CSVService.swift
//  Lagom Ledger
//
//  CSV 匯出/匯入
//

import Foundation
import UniformTypeIdentifiers

struct CSVService {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "zh_TW")
        return f
    }()
    
    static func exportCSV(transactions: [Transaction]) -> String {
        let bom = "\u{FEFF}"
        var csv = bom + "類型,類別,金額,名稱,發票號碼,日期\n"
        for t in transactions {
            let name = (t.name ?? "").replacingOccurrences(of: ",", with: "，")
            let invoice = (t.invoiceNumber ?? "").replacingOccurrences(of: ",", with: "，")
            let dateStr = dateFormatter.string(from: t.date)
            csv += "\(t.type.rawValue),\(t.category),\(Int(t.amount)),\"\(name)\",\"\(invoice)\",\(dateStr)\n"
        }
        return csv
    }
    
    static func parseCSV(_ content: String) -> [Transaction] {
        let cleaned = content.hasPrefix("\u{FEFF}") ? String(content.dropFirst()) : content
        let lines = cleaned.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }
        
        var results: [Transaction] = []
        for (index, line) in lines.enumerated() {
            if index == 0 && line.hasPrefix("類型") { continue }
            
            let parsed = parseCSVLine(line)
            guard parsed.count >= 4 else { continue }
            
            let typeStr = parsed[0]
            let category = parsed[1]
            guard let amount = Double(parsed[2]) else { continue }
            let name = parsed.count > 3 ? parsed[3].isEmpty ? nil : parsed[3] : nil
            var invoiceNumber: String? = nil
            var date = Date()
            if parsed.count >= 6 {
                invoiceNumber = parsed[4].isEmpty ? nil : parsed[4]
                if let d = dateFormatter.date(from: parsed[5]) { date = d }
            } else if parsed.count >= 5, let d = dateFormatter.date(from: parsed[4]) {
                date = d
            }
            
            let type: TransactionType = (typeStr == "收入") ? .income : .expense
            results.append(Transaction(type: type, category: category, amount: amount, name: name, invoiceNumber: invoiceNumber, date: date))
        }
        return results.sorted { $0.date > $1.date }
    }
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if (char == "," && !inQuotes) {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current.trimmingCharacters(in: .whitespaces))
        return result
    }
}
