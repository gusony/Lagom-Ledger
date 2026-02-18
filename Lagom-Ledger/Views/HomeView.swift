//
//  HomeView.swift
//  Lagom Ledger
//
//  主畫面：年月日曆選擇 + 交易列表
//

import SwiftUI

enum TimePeriod: String, CaseIterable {
    case year = "年"
    case month = "月"
    case day = "日"
}

struct HomeView: View {
    @StateObject private var store = TransactionStore.shared
    @State private var selectedPeriod: TimePeriod = .month
    @State private var selectedDate = Date()
    
    private var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .year:
            return store.transactions(for: calendar.component(.year, from: selectedDate))
        case .month:
            return store.transactions(
                for: calendar.component(.year, from: selectedDate),
                month: calendar.component(.month, from: selectedDate)
            )
        case .day:
            return store.transactions(for: selectedDate)
        }
    }
    
    private var periodTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        switch selectedPeriod {
        case .year:
            formatter.dateFormat = "yyyy 年"
        case .month:
            formatter.dateFormat = "yyyy 年 M 月"
        case .day:
            formatter.dateFormat = "yyyy/M/d"
        }
        return formatter.string(from: selectedDate)
    }
    
    private var totalAmount: (income: Double, expense: Double) {
        let income = filteredTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
        let expense = filteredTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
        return (income, expense)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 固定頂部：年/月/日 選取 bar（不捲動，避免與日曆重疊）
                VStack(spacing: 0) {
                    Picker("時間區段", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.secondarySystemGroupedBackground))
                
                Divider()
                    .background(Color(.separator))
                
                // 可捲動區域：日曆 + 摘要 + 交易列表
                ScrollView {
                    VStack(spacing: 0) {
                        // 年/月/日 選取器內容
                        VStack(spacing: 0) {
                            switch selectedPeriod {
                            case .year:
                                yearPicker
                            case .month:
                                monthPicker
                            case .day:
                                dayPicker
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                        
                        summaryCard
                        
                        Divider()
                            .background(Color(.separator))
                        
                        // 交易列表（長按可刪除）
                        LazyVStack(spacing: 0) {
                            ForEach(filteredTransactions) { transaction in
                                TransactionRowView(transaction: transaction)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemBackground))
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        Button("刪除", role: .destructive) {
                                            store.delete(transaction)
                                        }
                                    }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Lagom Ledger")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var yearPicker: some View {
        Picker("年", selection: Binding(
            get: { Calendar.current.component(.year, from: selectedDate) },
            set: { newYear in
                var components = Calendar.current.dateComponents([.month, .day], from: selectedDate)
                components.year = newYear
                selectedDate = Calendar.current.date(from: components) ?? selectedDate
            }
        )) {
            ForEach(2020...2030, id: \.self) { year in
                Text("\(year) 年").tag(year)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 120)
    }
    
    private var monthPicker: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...12, id: \.self) { month in
                let isSelected = Calendar.current.component(.month, from: selectedDate) == month
                Button {
                    var components = Calendar.current.dateComponents([.year, .day], from: selectedDate)
                    components.month = month
                    selectedDate = Calendar.current.date(from: components) ?? selectedDate
                } label: {
                    Text("\(month)月")
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var dayPicker: some View {
        DatePicker(
            "選擇日期",
            selection: $selectedDate,
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .frame(height: 300)
        .padding(.top, 8)
    }
    
    private var summaryCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("收入")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("$\(Int(totalAmount.income))")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("支出")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("$\(Int(totalAmount.expense))")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func deleteTransactions(at offsets: IndexSet) {
        let toDelete = offsets.map { filteredTransactions[$0] }
        for transaction in toDelete {
            store.delete(transaction)
        }
    }
}

#Preview {
    HomeView()
}
