//
//  ReportView.swift
//  Lagom Ledger
//
//  每月報表：消費走勢、類別比例
//

import SwiftUI
import Charts

struct ReportView: View {
    @StateObject private var store = TransactionStore.shared
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    
    private var monthlyData: [(label: String, amount: Double)] {
        store.monthlyExpenseTotals(months: 12).map { item in
            let label = "\(item.month)/\(item.year % 100)"
            return (label, item.amount)
        }
    }
    
    private var categoryData: [(category: String, amount: Double)] {
        store.expenseByCategory(year: selectedYear, month: selectedMonth)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 月份選擇
                    monthSelector
                    
                    // 逐月支出走勢
                    monthlyTrendSection
                    
                    // 類別花費比例
                    categoryPieSection
                }
                .padding()
            }
            .navigationTitle("報表")
        }
    }
    
    private var monthSelector: some View {
        HStack {
            Text("選擇月份")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("月", selection: $selectedMonth) {
                ForEach(1...12, id: \.self) { m in
                    Text("\(m)月").tag(m)
                }
            }
            .pickerStyle(.menu)
            Picker("年", selection: $selectedYear) {
                ForEach(2020...2030, id: \.self) { y in
                    Text("\(y)年").tag(y)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var monthlyTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("逐月支出走勢")
                .font(.headline)
            
            if monthlyData.isEmpty || monthlyData.allSatisfy({ $0.amount == 0 }) {
                Text("尚無資料")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                Chart(monthlyData, id: \.label) { item in
                    BarMark(
                        x: .value("月份", item.label),
                        y: .value("金額", item.amount)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var categoryPieSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(selectedYear)年\(selectedMonth)月 類別花費比例")
                .font(.headline)
            
            if categoryData.isEmpty {
                Text("本月尚無支出")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                Chart(categoryData, id: \.category) { item in
                    SectorMark(
                        angle: .value("金額", item.amount),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(by: .value("類別", item.category))
                }
                .frame(height: 220)
                
                // 圖例
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(categoryData, id: \.category) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(colorForCategory(item.category))
                                .frame(width: 8, height: 8)
                            Text(item.category)
                                .font(.caption)
                            Text("$\(Int(item.amount))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func colorForCategory(_ category: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .indigo, .mint]
        let index = abs(category.hashValue) % colors.count
        return colors[index]
    }
}

#Preview {
    ReportView()
}
