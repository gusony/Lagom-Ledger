//
//  TransactionRowView.swift
//  Lagom Ledger
//
//  交易列表單筆顯示
//

import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "M/d"
        return formatter.string(from: transaction.date)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 縮圖或圖示
            if let imageData = transaction.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: transaction.type == .income ? "arrow.down.circle" : "arrow.up.circle")
                    .font(.title2)
                    .foregroundStyle(transaction.type == .income ? .green : .red)
                    .frame(width: 44, height: 44)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.name ?? transaction.category)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(transaction.category) · \(dateString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("\(transaction.type == .expense ? "-" : "+")$\(Int(transaction.amount))")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(transaction.type == .income ? .green : .primary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        TransactionRowView(transaction: Transaction(
            type: .expense,
            category: ExpenseCategory.food.rawValue,
            amount: 150,
            name: "午餐",
            date: Date()
        ))
        TransactionRowView(transaction: Transaction(
            type: .income,
            category: IncomeCategory.salary.rawValue,
            amount: 50000,
            name: nil,
            date: Date()
        ))
    }
}
