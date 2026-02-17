//
//  MainTabView.swift
//  Lagom Ledger
//
//  主畫面 Tab 導覽
//

import SwiftUI

struct MainTabView: View {
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
    }
}

#Preview {
    MainTabView()
}
