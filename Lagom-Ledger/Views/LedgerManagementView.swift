//
//  LedgerManagementView.swift
//  Lagom Ledger
//
//  記帳本管理：新增、刪除
//

import SwiftUI
import UniformTypeIdentifiers

struct LedgerManagementView: View {
    @StateObject private var ledgerStore = LedgerStore.shared
    @StateObject private var transactionStore = TransactionStore.shared
    
    @State private var newLedgerName = ""
    @State private var showAddAlert = false
    @State private var ledgerToDelete: Ledger?
    @State private var showDeleteConfirm = false
    @State private var showExportSheet = false
    @State private var exportDocument: CSVExportDocument?
    @State private var showMessage = false
    @State private var messageText = ""
    
    var body: some View {
        List {
            Section {
                ForEach(ledgerStore.ledgers) { ledger in
                    HStack {
                        Text(ledger.name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if ledgerStore.ledgers.count > 1 {
                            Button(role: .destructive) {
                                ledgerToDelete = ledger
                                showDeleteConfirm = true
                            } label: {
                                Label("刪除", systemImage: "minus")
                            }
                        }
                    }
                }
                
                Button {
                    showAddAlert = true
                } label: {
                    Label("新增記帳本", systemImage: "plus.circle")
                }
            } header: {
                Text("記帳本")
            } footer: {
                Text(ledgerStore.ledgers.count > 1
                     ? "左滑記帳本名稱可刪除。刪除記帳本會一併刪除該記帳本內的所有交易紀錄。"
                     : "至少需保留一個記帳本。新增更多記帳本後即可刪除。")
            }
        }
        .navigationTitle("記帳本")
        .alert("新增記帳本", isPresented: $showAddAlert) {
            TextField("記帳本名稱", text: $newLedgerName)
            Button("取消", role: .cancel) {
                newLedgerName = ""
            }
            Button("新增") {
                ledgerStore.addLedger(name: newLedgerName)
                newLedgerName = ""
            }
        } message: {
            Text("輸入記帳本名稱")
        }
        .confirmationDialog("刪除記帳本", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("取消", role: .cancel) {
                ledgerToDelete = nil
            }
            Button("不匯出並刪除", role: .destructive) {
                performDelete(export: false)
            }
            Button("匯出並刪除", role: .destructive) {
                performDelete(export: true)
            }
        } message: {
            if let ledger = ledgerToDelete {
                Text("刪除「\(ledger.name)」會連同這個記帳本的所有紀錄都刪除，確定嗎？是否要幫您匯出後，再刪除？")
            }
        }
        .fileExporter(
            isPresented: $showExportSheet,
            document: exportDocument ?? CSVExportDocument(),
            contentType: .commaSeparatedText,
            defaultFilename: "\(ledgerToDelete?.name ?? "記帳本")_\(dateStringForExport).csv"
        ) { result in
            switch result {
            case .success:
                performDelete(export: false)
                messageText = "已匯出並刪除記帳本。"
                showMessage = true
            case .failure(let error):
                messageText = "匯出失敗：\(error.localizedDescription)"
                showMessage = true
            }
            exportDocument = nil
        }
        .alert("", isPresented: $showMessage) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(messageText)
        }
    }
    
    private var dateStringForExport: String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return f.string(from: Date())
    }
    
    private func performDelete(export: Bool) {
        guard let ledger = ledgerToDelete else { return }
        
        if export {
            let transactions = transactionStore.transactions(ledgerId: ledger.id)
            let csv = CSVService.exportCSV(transactions: transactions)
            exportDocument = CSVExportDocument(csvContent: csv)
            showExportSheet = true
        } else {
            transactionStore.deleteTransactions(ledgerId: ledger.id)
            ledgerStore.deleteLedger(ledger)
            ledgerToDelete = nil
            messageText = "已刪除「\(ledger.name)」。"
            showMessage = true
        }
    }
}
