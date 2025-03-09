//
//  ContentView.swift
//  Vizion Gateway
//
//  Created by Andre Browne on 1/13/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            TransactionMonitoringView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet")
                }
            
            RevenueAnalyticsView()
                .tabItem {
                    Label("Revenue", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            FraudDetectionView()
                .tabItem {
                    Label("Fraud", systemImage: "exclamationmark.shield")
                }
            
            MerchantManagementView()
                .tabItem {
                    Label("Merchants", systemImage: "building.2")
                }
            
            DisputeManagementView()
                .tabItem {
                    Label("Disputes", systemImage: "person.crop.circle.badge.exclamationmark")
                }
            
            ConnectedBanksView()
                .tabItem {
                    Label("Banks", systemImage: "building.columns")
                }
            
            SettlementAccountsView()
                .tabItem {
                    Label("Accounts", systemImage: "creditcard")
                }
            
            APIKeysView()
                .tabItem {
                    Label("API", systemImage: "key")
                }
            
            WebhookEventsView()
                .tabItem {
                    Label("Webhooks", systemImage: "arrow.triangle.branch")
                }
            
            SystemSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [User.self, Transaction.self], inMemory: true)
}
