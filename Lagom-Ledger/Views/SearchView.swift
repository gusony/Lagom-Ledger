//
//  SearchView.swift
//  Lagom Ledger
//
//  搜尋：依日期範圍、名稱
//

import SwiftUI

struct SearchView: View {
    @StateObject private var store = TransactionStore.shared
    @State private var nameText: String = ""
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var useDateRange = false
    
    @FocusState private var isNameFocused: Bool
    
    private var searchResults: [Transaction] {
        store.search(startDate: useDateRange ? startDate : nil, endDate: useDateRange ? endDate : nil, name: nameText)
    }
    
    private var hasSearchInput: Bool {
        useDateRange || !nameText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 固定頂部：日期範圍 + 名稱（不捲動）
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("使用日期範圍", isOn: $useDateRange)
                        
                        if useDateRange {
                            DatePicker("開始日期", selection: Binding(
                                get: { startDate ?? Date() },
                                set: { startDate = $0 }
                            ), displayedComponents: .date)
                            
                            DatePicker("結束日期", selection: Binding(
                                get: { endDate ?? Date() },
                                set: { endDate = $0 }
                            ), displayedComponents: .date)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    
                    TextField("名稱、類別或發票號碼", text: $nameText)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                        .focused($isNameFocused)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                Divider()
                
                // 搜尋結果（鍵盤出現時可被遮住，不往上推）
                Group {
                    if !hasSearchInput {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 80))
                                .foregroundStyle(.secondary)
                            Text("輸入名稱、類別、發票號碼或設定日期範圍搜尋")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { dismissKeyboard() }
                    } else if searchResults.isEmpty {
                        ContentUnavailableView(
                            "無符合結果",
                            systemImage: "magnifyingglass",
                            description: Text("嘗試不同的日期範圍或名稱")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { dismissKeyboard() }
                    } else {
                        List {
                            ForEach(searchResults) { transaction in
                                TransactionRowView(transaction: transaction)
                            }
                            .onDelete(perform: deleteFromResults)
                        }
                        .listStyle(.insetGrouped)
                        .scrollDismissesKeyboard(.immediately)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.keyboard)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        dismissKeyboard()
                    }
                }
            }
            .navigationTitle("搜尋")
        }
        .onAppear {
            if startDate == nil { startDate = Date() }
            if endDate == nil { endDate = Date() }
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func deleteFromResults(at offsets: IndexSet) {
        for index in offsets {
            let transaction = searchResults[index]
            store.delete(transaction)
        }
    }
}

#Preview {
    SearchView()
}
