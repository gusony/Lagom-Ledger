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
    
    enum CodingKeys: String, CodingKey {
        case id, type, category, amount, name, invoiceNumber, imageData, date
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        type = try c.decode(TransactionType.self, forKey: .type)
        category = try c.decode(String.self, forKey: .category)
        amount = try c.decode(Double.self, forKey: .amount)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        invoiceNumber = try c.decodeIfPresent(String.self, forKey: .invoiceNumber)
        imageData = try c.decodeIfPresent(Data.self, forKey: .imageData)
        date = try c.decode(Date.self, forKey: .date)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(category, forKey: .category)
        try c.encode(amount, forKey: .amount)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(invoiceNumber, forKey: .invoiceNumber)
        try c.encodeIfPresent(imageData, forKey: .imageData)
        try c.encode(date, forKey: .date)
    }
    var id: UUID
    var type: TransactionType
    var category: String  // 儲存 rawValue
    var amount: Double
    var name: String?
    var invoiceNumber: String?  // 電子發票字軌號碼（選填）
    var imageData: Data?
    var date: Date
    
    init(
        id: UUID = UUID(),
        type: TransactionType,
        category: String,
        amount: Double,
        name: String? = nil,
        invoiceNumber: String? = nil,
        imageData: Data? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.amount = amount
        self.name = name
        self.invoiceNumber = invoiceNumber
        self.imageData = imageData
        self.date = date
    }
    
    var categoryDisplayName: String { category }
    var amountDisplay: String { String(format: "%.0f", amount) }
}
