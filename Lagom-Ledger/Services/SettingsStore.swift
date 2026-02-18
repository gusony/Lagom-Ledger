//
//  SettingsStore.swift
//  Lagom Ledger
//
//  設定儲存
//

import Foundation
import SwiftUI

@MainActor
class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    private let backupKey = "iCloudBackupEnabled"
    private let retentionKey = "DataRetentionMonths"
    
    @Published var iCloudBackupEnabled: Bool {
        didSet { UserDefaults.standard.set(iCloudBackupEnabled, forKey: backupKey) }
    }
    
    /// 資料保留月數，0 = 不限制
    @Published var dataRetentionMonths: Int {
        didSet { UserDefaults.standard.set(dataRetentionMonths, forKey: retentionKey) }
    }
    
    private init() {
        self.iCloudBackupEnabled = UserDefaults.standard.bool(forKey: backupKey)
        self.dataRetentionMonths = UserDefaults.standard.object(forKey: retentionKey) as? Int ?? 0
    }
}
