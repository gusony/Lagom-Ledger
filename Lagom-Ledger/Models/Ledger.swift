//
//  Ledger.swift
//  Lagom Ledger
//
//  記帳本模型
//

import Foundation

struct Ledger: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
