//
//  MainTabView.swift
//  Lagom Ledger
//
//  主畫面 Tab 導覽
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var lotteryState: LotteryAppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("主畫面", systemImage: "house.fill")
                }
                .tag(0)
            
            AddTransactionView(isEmbeddedInTab: true)
                .tabItem {
                    Label("添加", systemImage: "plus")
                }
                .tag(1)
            
            ReportView()
                .tabItem {
                    Label("報表", systemImage: "chart.pie.fill")
                }
                .tag(2)
            
            SearchView()
                .tabItem {
                    Label("搜尋", systemImage: "magnifyingglass")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .alert("恭喜中獎！", isPresented: Binding(
            get: { lotteryState.pendingLotteryAlert != nil },
            set: { if !$0 { lotteryState.pendingLotteryAlert = nil } }
        )) {
            Button("太棒了", role: .cancel) {
                lotteryState.pendingLotteryAlert = nil
            }
        } message: {
            if let summary = lotteryState.pendingLotteryAlert {
                let msg = summary.byPeriod.map { "\($0.key)：\($0.value.count) 張，共 $\($0.value.amount)" }.joined(separator: "\n")
                Text("\(msg)\n\n總計：\(summary.wins.count) 張，$\(summary.totalAmount)")
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(LotteryAppState.shared)
}
