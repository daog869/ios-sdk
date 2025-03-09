//
//  ContentView.swift
//  Vizion Gateway
//
//  Created by Andre Browne on 1/13/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Int = 0
    @State private var showSidePanel: Bool = true
    @State private var isPanelPinned: Bool = true
    @State private var environment: AppEnvironment = .sandbox
    @State private var showEnvironmentPicker: Bool = false
    
    // List of all tab items
    private var tabItems: [TabItem] {
        [
            TabItem(title: "Dashboard", icon: "square.grid.2x2", view: AnyView(DashboardView())),
            TabItem(title: "Transactions", icon: "list.bullet", view: AnyView(TransactionMonitoringView())),
            TabItem(title: "API Keys", icon: "key.fill", view: AnyView(APIKeysView())),
            TabItem(title: "API Webhooks", icon: "arrow.triangle.branch", view: AnyView(WebhookEventsView())),
            TabItem(title: "Merchants", icon: "building.2", view: AnyView(MerchantManagementView())),
            TabItem(title: "Users", icon: "person.2.fill", view: AnyView(UserManagementView())),
            TabItem(title: "Disputes", icon: "exclamationmark.shield", view: AnyView(DisputeManagementView())),
            TabItem(title: "Banks", icon: "building.columns", view: AnyView(ConnectedBanksView())),
            TabItem(title: "Accounts", icon: "creditcard", view: AnyView(SettlementAccountsView())),
            TabItem(title: "Analytics", icon: "chart.line.uptrend.xyaxis", view: AnyView(RevenueAnalyticsView())),
            TabItem(title: "Settings", icon: "gear", view: AnyView(SystemSettingsView()))
        ]
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Side tab panel
                if showSidePanel {
                    VStack(spacing: 0) {
                        // Header with environment selector
                        VStack(spacing: 0) {
                            HStack {
                                Button(action: {
                                    withAnimation {
                                        showEnvironmentPicker.toggle()
                                    }
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(environment == .sandbox ? Color.orange : Color.green)
                                            .frame(width: 10, height: 10)
                                        
                                        Text(environment.rawValue.capitalized)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.1))
                                    .cornerRadius(16)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation {
                                        isPanelPinned.toggle()
                                    }
                                }) {
                                    Image(systemName: isPanelPinned ? "pin.fill" : "pin.slash")
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            
                            if showEnvironmentPicker {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(AppEnvironment.allCases, id: \.self) { env in
                                        Button(action: {
                                            withAnimation {
                                                changeEnvironment(to: env)
                                                showEnvironmentPicker = false
                                            }
                                        }) {
                                            HStack {
                                                Circle()
                                                    .fill(env == .sandbox ? Color.orange : Color.green)
                                                    .frame(width: 8, height: 8)
                                                Text(env.rawValue.capitalized)
                                                    .font(.subheadline)
                                                
                                                Spacer()
                                                
                                                if environment == env {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption)
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 16)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        if env != AppEnvironment.allCases.last {
                                            Divider()
                                                .padding(.leading, 16)
                                        }
                                    }
                                }
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.1), radius: 4)
                                .padding(.horizontal, 12)
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                            }
                            
                            Divider()
                        }
                        .background(Color(UIColor.systemBackground))
                        
                        // Tab buttons
                        ScrollView {
                            VStack(spacing: 5) {
                                ForEach(0..<tabItems.count, id: \.self) { index in
                                    TabButton(
                                        title: tabItems[index].title,
                                        icon: tabItems[index].icon,
                                        isSelected: selectedTab == index,
                                        action: {
                                            selectedTab = index
                                            if !isPanelPinned {
                                                withAnimation {
                                                    showSidePanel = false
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    .frame(width: geometry.size.width * 0.25)
                    .background(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(Color(UIColor.separator))
                            .opacity(0.5),
                        alignment: .trailing
                    )
                    .transition(.move(edge: .leading))
                }
                
                // Content area
                ZStack(alignment: .topLeading) {
                    // Environment Indicator
                    VStack {
                        HStack(spacing: 8) {
                            // Environment indicator pill
                            if environment == .sandbox {
                                Text("SANDBOX MODE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(Color.orange)
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        Spacer()
                    }
                    .zIndex(1)
                    
                    // Current tab view
                    tabItems[selectedTab].view
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Tab toggle button (appears only when panel is hidden or not pinned)
                    if !showSidePanel || !isPanelPinned {
                        Button(action: {
                            withAnimation {
                                showSidePanel.toggle()
                                if showEnvironmentPicker {
                                    showEnvironmentPicker = false
                                }
                            }
                        }) {
                            Image(systemName: "sidebar.left")
                                .font(.title2)
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        .padding()
                        .transition(.opacity)
                        .zIndex(2)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: selectedTab) { _, _ in
            // Close environment picker if open when changing tabs
            if showEnvironmentPicker {
                withAnimation {
                    showEnvironmentPicker = false
                }
            }
        }
        .onAppear {
            // Load current environment from FirebaseManager
            loadCurrentEnvironment()
        }
    }
    
    // MARK: - Environment Methods
    
    private func loadCurrentEnvironment() {
        // Get saved environment from UserDefaults
        if let savedEnv = UserDefaults.standard.string(forKey: "environment"),
           let env = AppEnvironment(rawValue: savedEnv) {
            environment = env
        }
    }
    
    private func changeEnvironment(to newEnvironment: AppEnvironment) {
        environment = newEnvironment
        
        // Update environment in FirebaseManager
        FirebaseManager.shared.setEnvironment(newEnvironment)
    }
}

// MARK: - Supporting Types

enum AppEnvironment: String, CaseIterable {
    case sandbox
    case production
}

// Represents a tab item in our app
struct TabItem {
    let title: String
    let icon: String
    let view: AnyView
}

// A custom button for the side tab panel
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .accentColor : .primary)
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accentColor : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 8)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [MerchantUser.self, PaymentTransaction.self], inMemory: true)
}
