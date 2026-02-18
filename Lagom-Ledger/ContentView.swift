//
//  ContentView.swift
//  Accounting
//
//  Hello World 主畫面
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("Hello, 記帳!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("部署成功！")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("這是一個簡單的記帳 App 起點")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    ContentView()
}
