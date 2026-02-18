//
//  SettingsView.swift
//  Lagom Ledger
//
//  設定
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @StateObject private var settingsStore = SettingsStore.shared
    @StateObject private var transactionStore = TransactionStore.shared
    
    @State private var showBackupAlert = false
    @State private var backupMessage = ""
    @State private var showClearConfirm = false
    @State private var showRestoreConfirm = false
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var exportDocument: CSVExportDocument?
    @State private var isLotteryChecking = false
    @State private var showLotteryResult = false
    @State private var lotteryResultMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                // 記帳本管理
                Section {
                    NavigationLink {
                        LedgerManagementView()
                    } label: {
                        Label("記帳本", systemImage: "book.closed")
                    }
                } header: {
                    Text("記帳本")
                } footer: {
                    Text("新增、刪除記帳本。刪除會一併刪除該記帳本內的所有交易。")
                }
                
                // 對獎
                Section {
                    Button {
                        runLotteryCheck()
                    } label: {
                        Label("對獎", systemImage: "gift")
                        if isLotteryChecking {
                            Spacer()
                            ProgressView()
                        }
                    }
                    .disabled(isLotteryChecking)
                } header: {
                    Text("對獎")
                } footer: {
                    Text("比對最近六個月內有發票號碼的紀錄與最近三期開獎號碼。")
                }
                
                // 資料匯出/匯入
                Section {
                    Button {
                        exportCSV()
                    } label: {
                        Label("匯出 CSV", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        showImportPicker = true
                    } label: {
                        Label("匯入 CSV", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("資料")
                } footer: {
                    Text("匯出為 CSV 格式，可於 Excel 等軟體開啟。匯入會將 CSV 資料加入現有記錄。")
                }
                
                // iCloud 備份
                Section {
                    Toggle("iCloud 備份", isOn: $settingsStore.iCloudBackupEnabled)
                        .onChange(of: settingsStore.iCloudBackupEnabled) { _, newValue in
                            if newValue { backupToiCloud() }
                        }
                    
                    Button("從 iCloud 還原") {
                        showRestoreConfirm = true
                    }
                } header: {
                    Text("備份")
                } footer: {
                    Text("開啟後，記帳資料會備份至 iCloud。還原會以 iCloud 資料覆蓋本機。")
                }
                
                // 資料管理
                Section {
                    Picker("資料保留", selection: $settingsStore.dataRetentionMonths) {
                        Text("不限制").tag(0)
                        Text("最近 6 個月").tag(6)
                        Text("最近 12 個月").tag(12)
                        Text("最近 24 個月").tag(24)
                        Text("最近 36 個月").tag(36)
                    }
                    
                    Button("套用保留限制", role: .destructive) {
                        transactionStore.applyRetentionLimit()
                        backupMessage = "已刪除超過保留期限的舊資料。"
                        showBackupAlert = true
                    }
                    
                    Button("清除所有資料", role: .destructive) {
                        showClearConfirm = true
                    }
                } header: {
                    Text("資料管理")
                } footer: {
                    Text("設定保留期限後，超過的舊資料會被刪除。清除所有資料無法復原。")
                }
                
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
            .alert("備份", isPresented: $showBackupAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(backupMessage)
            }
            .alert("對獎結果", isPresented: $showLotteryResult) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(lotteryResultMessage)
            }
            .confirmationDialog("清除所有資料", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清除", role: .destructive) {
                    transactionStore.clearAll()
                    backupMessage = "已清除所有資料。"
                    showBackupAlert = true
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("此操作無法復原，確定要清除所有記帳資料嗎？")
            }
            .confirmationDialog("從 iCloud 還原", isPresented: $showRestoreConfirm, titleVisibility: .visible) {
                Button("還原", role: .destructive) {
                    if transactionStore.restoreFromiCloud() {
                        backupMessage = "已從 iCloud 還原資料。"
                    } else {
                        backupMessage = "還原失敗，請確認 iCloud 備份已開啟且有備份資料。"
                    }
                    showBackupAlert = true
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("還原會以 iCloud 備份覆蓋本機資料，本機現有資料將被取代。")
            }
            .fileExporter(
                isPresented: $showExportSheet,
                document: exportDocument ?? CSVExportDocument(),
                contentType: .commaSeparatedText,
                defaultFilename: "lagom_ledger_\(dateStringForExport).csv"
            ) { result in
                if case .failure(let error) = result {
                    backupMessage = "匯出失敗：\(error.localizedDescription)"
                    showBackupAlert = true
                }
                exportDocument = nil
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        do {
                            let data = try Data(contentsOf: url)
                            let content = String(data: data, encoding: .utf8) ?? ""
                            var imported = CSVService.parseCSV(content)
                            let defaultLedgerId = LedgerStore.shared.ledgers.first?.id
                            for i in imported.indices {
                                imported[i].ledgerId = imported[i].ledgerId ?? defaultLedgerId
                            }
                            transactionStore.importFromCSV(imported)
                            backupMessage = "已匯入 \(imported.count) 筆資料。"
                        } catch {
                            backupMessage = "匯入失敗：\(error.localizedDescription)"
                        }
                    } else {
                        backupMessage = "無法讀取檔案。"
                    }
                    showBackupAlert = true
                case .failure(let error):
                    backupMessage = "匯入失敗：\(error.localizedDescription)"
                    showBackupAlert = true
                }
            }
        }
    }
    
    private var dateStringForExport: String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return f.string(from: Date())
    }
    
    private func exportCSV() {
        let csv = CSVService.exportCSV(transactions: transactionStore.transactions)
        exportDocument = CSVExportDocument(csvContent: csv)
        showExportSheet = true
    }
    
    private func handleBackupToggle() {
        if settingsStore.iCloudBackupEnabled {
            backupToiCloud()
        }
    }
    
    private func backupToiCloud() {
        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            backupMessage = "iCloud 無法使用，請確認已登入 Apple ID 並在 Xcode 專案中啟用 iCloud 能力。"
            showBackupAlert = true
            settingsStore.iCloudBackupEnabled = false
            return
        }
        
        let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("transactions.json")
        let iCloudBackupURL = iCloudURL.appendingPathComponent("Documents/transactions.json")
        
        do {
            try FileManager.default.createDirectory(
                at: iCloudBackupURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: iCloudBackupURL.path) {
                try FileManager.default.removeItem(at: iCloudBackupURL)
            }
            if FileManager.default.fileExists(atPath: localURL.path) {
                try FileManager.default.copyItem(at: localURL, to: iCloudBackupURL)
            } else {
                try Data().write(to: iCloudBackupURL)
            }
            backupMessage = "備份已開始同步至 iCloud。"
        } catch {
            backupMessage = "備份失敗：\(error.localizedDescription)"
            settingsStore.iCloudBackupEnabled = false
        }
        showBackupAlert = true
    }
    
    private func runLotteryCheck() {
        isLotteryChecking = true
        Task { @MainActor in
            if let summary = await LotteryChecker.shared.runCheck(transactions: transactionStore.transactions) {
                LotteryChecker.shared.markChecked()
                if summary.wins.isEmpty {
                    lotteryResultMessage = "本次未中獎。已比對最近六個月內有發票號碼的紀錄。"
                } else {
                    let msg = summary.byPeriod.map { "\($0.key)：\($0.value.count) 張，共 $\($0.value.amount)" }.joined(separator: "\n")
                    lotteryResultMessage = "恭喜中獎！\n\n\(msg)\n\n總計：\(summary.wins.count) 張，$\(summary.totalAmount)"
                }
            } else {
                lotteryResultMessage = "對獎失敗，請檢查網路連線後重試。"
            }
            isLotteryChecking = false
            showLotteryResult = true
        }
    }
}

// 用於 fileExporter 的 CSV Document
struct CSVExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    var csvContent: String
    
    init(csvContent: String = "") {
        self.csvContent = csvContent
    }
    
    init(configuration: ReadConfiguration) throws {
        csvContent = configuration.file.regularFileContents.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(csvContent.utf8))
    }
}

#Preview {
    SettingsView()
}
