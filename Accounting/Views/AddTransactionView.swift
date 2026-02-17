//
//  AddTransactionView.swift
//  Lagom Ledger
//
//  新增收入/支出
//

import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = TransactionStore.shared
    
    let type: TransactionType
    var isEmbeddedInTab: Bool = false
    
    @State private var selectedType: TransactionType
    @State private var selectedCategory: String = ""
    @State private var amountText: String = ""
    @State private var nameText: String = ""
    @State private var selectedDate = Date()
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var categories: [String] {
        selectedType == .expense
            ? ExpenseCategory.allCases.map(\.rawValue)
            : IncomeCategory.allCases.map(\.rawValue)
    }
    
    init(type: TransactionType = .expense, isEmbeddedInTab: Bool = false) {
        self.type = type
        self.isEmbeddedInTab = isEmbeddedInTab
        _selectedType = State(initialValue: type)
    }
    
    private var isValid: Bool {
        !selectedCategory.isEmpty && (Double(amountText) ?? 0) > 0
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
            .navigationTitle("新增記帳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isEmbeddedInTab {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("清除") { resetForm() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .disabled(!isValid)
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
        }
        .onAppear {
            if selectedCategory.isEmpty {
                selectedCategory = categories.first ?? ""
            }
        }
        .onChange(of: selectedType) { _ in
            selectedCategory = categories.first ?? ""
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
        
        let imageData = selectedImage?.jpegData(compressionQuality: 0.7)
        
        let transaction = Transaction(
            type: selectedType,
            category: selectedCategory,
            amount: amount,
            name: nameText.isEmpty ? nil : nameText,
            imageData: imageData,
            date: selectedDate
        )
        
        store.add(transaction)
        if isEmbeddedInTab {
            resetForm()
        } else {
            dismiss()
        }
    }
    
    private func resetForm() {
        amountText = ""
        nameText = ""
        selectedDate = Date()
        selectedImage = nil
        selectedCategory = categories.first ?? ""
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    AddTransactionView(type: .expense)
}
