//
//  InvoiceQRScannerView.swift
//  Lagom Ledger
//
//  掃描電子發票 QR Code（自動辨識左右條碼並合併）
//

import SwiftUI
import AVFoundation

struct InvoiceQRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (InvoiceQRResult) -> Void
    
    @State private var isAuthorized = false
    @State private var showPermissionAlert = false
    @State private var showParseError = false
    @State private var parseErrorMessage = ""
    @State private var lastInvalidQRTime: Date?
    
    // 累積掃描結果（先掃右方時暫存，等左方掃到後合併）
    @State private var rightStoreName: String?
    @State private var waitingForLeft = false  // 已掃右方，等待左方
    
    var body: some View {
        NavigationStack {
            Group {
                if isAuthorized {
                    VStack(spacing: 0) {
                        scanHintView
                        CameraQRScannerView { qrStrings in
                            handleScannedQRs(qrStrings)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "需要鏡頭權限",
                        systemImage: "camera.fill",
                        description: Text("請在設定中允許此 App 使用相機以掃描電子發票")
                    )
                }
            }
            .navigationTitle("掃描電子發票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("無法解析", isPresented: $showParseError) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(parseErrorMessage)
            }
            .onAppear {
                checkCameraPermission()
            }
        }
    }
    
    @ViewBuilder
    private var scanHintView: some View {
        if waitingForLeft {
            Text("已掃描右方條碼，請再掃描左方條碼")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .padding(.top, 8)
        } else {
            Text("請掃描發票上的二維條碼（左右皆可）")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }
    
    /// 處理掃描到的 QR Code（同一畫面可能有多個），回傳 true 表示完成並停止掃描
    private func handleScannedQRs(_ qrStrings: [String]) -> Bool {
        var foundLeft: InvoiceQRResult?
        var foundRightStoreName: String?
        
        for qrString in qrStrings {
            switch InvoiceQRParser.detectType(qrString) {
            case .left:
                if let result = InvoiceQRParser.parseLeftQR(qrString) {
                    foundLeft = result
                }
            case .right:
                foundRightStoreName = InvoiceQRParser.parseRightQR(qrString) ?? foundRightStoreName
            case nil:
                break
            }
        }
        
        // 若掃到左方（或同一畫面同時掃到左右），合併後回傳
        if let left = foundLeft {
            let rightName = foundRightStoreName ?? rightStoreName
            let merged = InvoiceQRParser.merge(left: left, rightStoreName: rightName)
            onScan(merged)
            dismiss()
            return true
        }
        
        // 僅掃到右方（** 開頭），等待左方
        if qrStrings.contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("**") }) {
            if let name = foundRightStoreName {
                rightStoreName = name
            }
            waitingForLeft = true
            return false
        }
        
        // 無效
        if !qrStrings.isEmpty {
            showGenericError()
        }
        return false
    }
    
    private func showGenericError() {
        let now = Date()
        if let last = lastInvalidQRTime, now.timeIntervalSince(last) < 2 { return }
        lastInvalidQRTime = now
        parseErrorMessage = "此 QR Code 並非電子發票格式，請掃描發票證明聯上的二維條碼"
        showParseError = true
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    isAuthorized = granted
                    if !granted {
                        showPermissionAlert = true
                    }
                }
            }
        default:
            showPermissionAlert = true
        }
    }
}

// MARK: - Camera QR Scanner
/// onDetect 接收同一畫面偵測到的所有 QR 字串，回傳 true 表示解析成功、停止掃描
struct CameraQRScannerView: UIViewControllerRepresentable {
    let onDetect: ([String]) -> Bool
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onDetect = onDetect
        return vc
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController {
    var onDetect: (([String]) -> Bool)?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasDetected = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasDetected = false
        if captureSession?.isRunning == false {
            captureSession?.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        
        session.addInput(input)
        
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        
        output.metadataObjectTypes = [.qr]
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        
        captureSession = session
        previewLayer = layer
        session.startRunning()
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasDetected else { return }
        
        let strings = metadataObjects.compactMap { obj -> String? in
            guard let qr = obj as? AVMetadataMachineReadableCodeObject,
                  qr.type == .qr else { return nil }
            return qr.stringValue
        }
        guard !strings.isEmpty else { return }
        
        let shouldStop = onDetect?(strings) ?? false
        if shouldStop {
            hasDetected = true
            captureSession?.stopRunning()
        }
    }
}
