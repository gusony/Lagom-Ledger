//
//  LedgerStore.swift
//  Lagom Ledger
//
//  記帳本管理與選取
//

import Foundation
import SwiftUI

@MainActor
class LedgerStore: ObservableObject {
    static let shared = LedgerStore()
    
    @Published var ledgers: [Ledger] = []
    /// nil = 全部
    @Published var selectedLedgerId: UUID?
    
    private let ledgersKey = "Ledgers"
    private let selectedLedgerIdKey = "SelectedLedgerId"
    
    private init() {
        load()
        if ledgers.isEmpty {
            ledgers = [Ledger(name: "個人記帳本")]
            save()
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: ledgersKey),
           let decoded = try? JSONDecoder().decode([Ledger].self, from: data) {
            ledgers = decoded
        }
        if let idStr = UserDefaults.standard.string(forKey: selectedLedgerIdKey),
           let id = UUID(uuidString: idStr),
           ledgers.contains(where: { $0.id == id }) {
            selectedLedgerId = id
        } else {
            selectedLedgerId = ledgers.first?.id
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(ledgers) {
            UserDefaults.standard.set(data, forKey: ledgersKey)
        }
        if let id = selectedLedgerId {
            UserDefaults.standard.set(id.uuidString, forKey: selectedLedgerIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedLedgerIdKey)
        }
    }
    
    var selectedLedger: Ledger? {
        guard let id = selectedLedgerId else { return nil }
        return ledgers.first { $0.id == id }
    }
    
    var isShowingAll: Bool {
        selectedLedgerId == nil
    }
    
    func selectLedger(_ id: UUID?) {
        selectedLedgerId = id
        save()
    }
    
    func addLedger(name: String) {
        let ledger = Ledger(name: name.trimmingCharacters(in: .whitespaces))
        guard !ledger.name.isEmpty else { return }
        ledgers.append(ledger)
        save()
    }
    
    func deleteLedger(_ ledger: Ledger) {
        ledgers.removeAll { $0.id == ledger.id }
        if selectedLedgerId == ledger.id {
            selectedLedgerId = ledgers.first?.id
        }
        save()
    }
    
    func ledgerName(for id: UUID) -> String? {
        ledgers.first { $0.id == id }?.name
    }
}
