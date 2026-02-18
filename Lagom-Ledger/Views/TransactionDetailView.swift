//
//  TransactionDetailView.swift
//  Lagom Ledger
//
//  檢視與編輯交易明細
//

import SwiftUI

struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = TransactionStore.shared
    @StateObject private var ledgerStore = LedgerStore.shared
    
    let transaction: Transaction
    
    @State private var selectedType: TransactionType
    @State private var selectedCategory: String
    @State private var selectedLedgerId: UUID?
    @State private var amountText: String
    @State private var nameText: String
    @State private var invoiceNumberText: String
    @State private var selectedDate: Date
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showInvoiceScanner = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var categories: [String] {
        selectedType == .expense
            ? ExpenseCategory.allCases.map(\.rawValue)
            : IncomeCategory.allCases.map(\.rawValue)
    }
    
    init(transaction: Transaction) {
        self.transaction = transaction
        _selectedType = State(initialValue: transaction.type)
        _selectedCategory = State(initialValue: transaction.category)
        _selectedLedgerId = State(initialValue: transaction.ledgerId)
        _amountText = State(initialValue: String(format: "%.0f", transaction.amount))
        _nameText = State(initialValue: transaction.name ?? "")
        _invoiceNumberText = State(initialValue: transaction.invoiceNumber ?? "")
        _selectedDate = State(initialValue: transaction.date)
        _selectedImage = State(initialValue: transaction.imageData.flatMap { UIImage(data: $0) })
    }
    
    private var isValid: Bool {
        selectedLedgerId != nil && !selectedCategory.isEmpty && (Double(amountText) ?? 0) > 0
    }
    
    private var hasChanges: Bool {
        selectedType != transaction.type ||
        selectedCategory != transaction.category ||
        selectedLedgerId != transaction.ledgerId ||
        (Double(amountText) ?? 0) != transaction.amount ||
        nameText != (transaction.name ?? "") ||
        invoiceNumberText != (transaction.invoiceNumber ?? "") ||
        !Calendar.current.isDate(selectedDate, inSameDayAs: transaction.date) ||
        selectedImage?.jpegData(compressionQuality: 0.7) != transaction.imageData
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("類型") {
                    Picker("類型", selection: $selectedType) {
                        Text("支出").tag(TransactionType.expense)
                        Text("收入").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("記帳本（必選）") {
                    Picker("記帳本", selection: $selectedLedgerId) {
                        Text("請選擇").tag(nil as UUID?)
                        ForEach(ledgerStore.ledgers) { ledger in
                            Text(ledger.name).tag(ledger.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("類別（必選）") {
                    Picker("類別", selection: $selectedCategory) {
                        Text("請選擇").tag("")
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("金額（必填）") {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section("名稱（選填）") {
                    TextField("消費或收入描述", text: $nameText)
                }
                
                if selectedType == .expense {
                    Section("發票號碼（選填）") {
                        HStack {
                            TextField("電子發票字軌號碼", text: $invoiceNumberText)
                            Button {
                                showInvoiceScanner = true
                            } label: {
                                Label("掃描", systemImage: "qrcode.viewfinder")
                            }
                        }
                    }
                }
                
                Section("日期") {
                    DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
                }
                
                Section("照片（選填）") {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button("移除照片", role: .destructive) {
                            selectedImage = nil
                        }
                    } else {
                        HStack(spacing: 16) {
                            Button {
                                imageSourceType = .camera
                                showCamera = true
                            } label: {
                                Label("拍照", systemImage: "camera.fill")
                            }
                            
                            Button {
                                imageSourceType = .photoLibrary
                                showImagePicker = true
                            } label: {
                                Label("相簿", systemImage: "photo.on.rectangle")
                            }
                        }
                    }
                }
            }
            .navigationTitle("明細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .disabled(!isValid || !hasChanges)
                }
            }
            .alert("錯誤", isPresented: $showError) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
            .sheet(isPresented: $showInvoiceScanner) {
                InvoiceQRScannerView { result in
                    invoiceNumberText = result.invoiceNumber
                    amountText = String(Int(result.totalAmount))
                    if let store = result.storeName {
                        nameText = store
                    }
                    if let date = result.invoiceDate {
                        selectedDate = date
                    }
                }
            }
        }
        .onChange(of: selectedType) { _, _ in
            if !categories.contains(selectedCategory) {
                selectedCategory = categories.first ?? ""
            }
        }
    }
    
    private func save() {
        guard let amount = Double(amountText), amount > 0 else {
            errorMessage = "請輸入有效金額"
            showError = true
            return
        }
        guard !selectedCategory.isEmpty else {
            errorMessage = "請選擇類別"
            showError = true
            return
        }
        guard let ledgerId = selectedLedgerId else {
            errorMessage = "請選擇記帳本"
            showError = true
            return
        }
        
        let imageData = selectedImage?.jpegData(compressionQuality: 0.7)
        
        var updated = transaction
        updated.type = selectedType
        updated.category = selectedCategory
        updated.amount = amount
        updated.name = nameText.isEmpty ? nil : nameText
        updated.invoiceNumber = invoiceNumberText.isEmpty ? nil : invoiceNumberText
        updated.imageData = imageData
        updated.date = selectedDate
        updated.ledgerId = ledgerId
        
        store.update(updated)
        dismiss()
    }
}

#Preview {
    TransactionDetailView(transaction: Transaction(
        type: .expense,
        category: ExpenseCategory.food.rawValue,
        amount: 150,
        name: "午餐",
        date: Date()
    ))
}
