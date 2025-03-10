//
//  ContentView.swift
//  Vizion Gateway
//
//  Created by Andre Browne on 1/13/25.
//

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @ObservedObject private var authManager = AuthorizationManager.shared
    @State private var showingError: VizionAppError?
    @State private var showAuthDebugger = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            switch authManager.authState {
            case .initializing:
                LoadingView()
                
            case .signedIn:
                MainTabView()
                
            case .signedOut:
                AppAuthenticationView()
            }
        }
        .withErrorHandling($showingError)
        .onChange(of: authManager.errorMessage) { _, newMessage in
            if let message = newMessage {
                showingError = .authError(message)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // Debug button only visible in development
            #if DEBUG
            Button {
                showAuthDebugger = true
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .padding(12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            .padding()
            .opacity(0.8)
            #endif
        }
        // Use the Firebase auth debugger from FirebaseAuthDebugger.swift
        .modifier(AuthDebuggerModifier(isShowing: $showAuthDebugger))
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image("AppLogo") // Replace with your app logo
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .padding()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading Vizion Gateway...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct AppAuthenticationView: View {
    @State private var showSignUp = false
    
    var body: some View {
        NavigationView {
            if showSignUp {
                SignUpView()
                    .environmentObject(AuthenticationManager.shared)
            } else {
                LoginView()
            }
        }
    }
}

struct MainTabView: View {
    @ObservedObject private var authManager = AuthorizationManager.shared
    @State private var selectedSidebarItem: String? = "Dashboard"
    
    var body: some View {
        Group {
            if let user = authManager.currentUser, user.role == .admin {
                // Admin view with side navigation
                NavigationSplitView {
                    AdminSidebarView(selection: $selectedSidebarItem)
                } detail: {
                    AdminDetailView(selection: selectedSidebarItem)
                }
            } else {
                // Regular user view with bottom tabs
                TabView {
                    DashboardView()
                        .tabItem {
                            Label("Dashboard", systemImage: "chart.bar")
                        }
                    
                    if let user = authManager.currentUser, user.role == .merchant {
                        NavigationStack {
                            POSView()
                        }
                        .tabItem {
                            Label("Point of Sale", systemImage: "creditcard.and.contactless")
                        }
                        
                        TransactionsView()
                            .tabItem {
                                Label("Transactions", systemImage: "list.bullet.rectangle")
                            }
                    } else {
                        CustomerTransactionsView()
                            .tabItem {
                                Label("My Transactions", systemImage: "arrow.left.arrow.right")
                            }
                        
                        SendFundsView()
                            .tabItem {
                                Label("Send Money", systemImage: "dollarsign.arrow.circlepath")
                            }
                    }
                    
                    UserProfileView(user: authManager.currentUser!)
                        .tabItem {
                            Label("Profile", systemImage: "person.circle")
                        }
                }
            }
        }
    }
}

struct AdminSidebarView: View {
    @Binding var selection: String?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthorizationManager.shared
    
    var body: some View {
        VStack {
            List(selection: $selection) {
                Group {
                    NavigationLink(value: "Dashboard") {
                        Label("Dashboard", systemImage: "chart.bar")
                    }
                    .padding(.vertical, 8)
                    
                    NavigationLink(value: "Transactions") {
                        Label("Transactions", systemImage: "arrow.left.arrow.right")
                    }
                    .padding(.vertical, 8)
                    
                    NavigationLink(value: "Merchants") {
                        Label("Merchants", systemImage: "building.2")
                    }
                    .padding(.vertical, 8)
                    
                    NavigationLink(value: "Users") {
                        Label("Users", systemImage: "person.3")
                    }
                    .padding(.vertical, 8)
                    
                    NavigationLink(value: "Analytics") {
                        Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .padding(.vertical, 8)
                    
                    NavigationLink(value: "Verifications") {
                        Label("Verifications", systemImage: "checkmark.shield")
                    }
                    .padding(.vertical, 8)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                
                // Developer Section
                Section("Developer") {
                    Group {
                        NavigationLink(value: "API Keys") {
                            Label("API Keys", systemImage: "key.fill")
                        }
                        .padding(.vertical, 8)
                        
                        NavigationLink(value: "Webhooks") {
                            Label("Webhooks", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        .padding(.vertical, 8)
                        
                        NavigationLink(value: "API Docs") {
                            Label("API Documentation", systemImage: "doc.text.fill")
                        }
                        .padding(.vertical, 8)
                        
                        NavigationLink(value: "SDK Guides") {
                            Label("SDK Guides", systemImage: "book.fill")
                        }
                        .padding(.vertical, 8)
                        
                        NavigationLink(value: "Test Tools") {
                            Label("Testing Tools", systemImage: "hammer.fill")
                        }
                        .padding(.vertical, 8)
                        
                        NavigationLink(value: "API Logs") {
                            Label("API Logs", systemImage: "text.alignleft")
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Admin Portal")
            
            Spacer()
            
            // Sign Out Button
            Button(action: {
                Task {
                    do {
                        try await authManager.signOut()
                    } catch {
                        print("Error signing out: \(error.localizedDescription)")
                    }
                }
            }) {
                HStack {
                    Spacer()
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground).opacity(0.2))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

struct AdminDetailView: View {
    let selection: String?
    
    var body: some View {
        contentView(for: selection)
    }
    
    @ViewBuilder
    private func contentView(for selection: String?) -> some View {
        switch selection {
        case "Dashboard":
            DashboardView()
        case "Transactions":
            TransactionsView()
        case "Merchants":
            MerchantManagementView()
        case "Users":
            UserManagementView()
        case "Analytics":
            RevenueAnalyticsView()
        case "Verifications":
            VerificationManagementView()
        case "API Keys":
            APIKeysView()
        case "Webhooks":
            WebhookAdminView()
        case "API Docs":
            APIDocumentationView()
        case "SDK Guides":
            SDKGuideView()
        case "Test Tools":
            TestTransactionView()
        case "API Logs":
            APILogsView()
        default:
            DashboardView()
        }
    }
}

// Customer-specific transaction view
struct CustomerTransactionsView: View {
    @ObservedObject private var authManager = AuthorizationManager.shared
    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    @State private var errorMessage: VizionAppError?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if transactions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.left.arrow.right.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.blue.opacity(0.7))
                        
                        Text("No Transactions")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("You haven't made any transactions yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("New Transaction") {
                            // Action to create a new transaction
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.top, 10)
                    }
                    .padding()
                } else {
                    List(transactions) { transaction in
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TransactionRow(transaction: transaction)
                        }
                    }
                    .refreshable {
                        await loadTransactions()
                    }
                }
            }
            .navigationTitle("My Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Create new transaction
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .withErrorHandling($errorMessage)
            .task {
                await loadTransactions()
            }
        }
    }
    
    private func loadTransactions() async {
        guard let userId = authManager.currentUser?.id else { return }
        
        isLoading = true
        
        do {
            // Load user's transactions from Firebase
            let userTransactions = try await FirebaseManager.shared.fetchUserTransactions(userId: userId)
            
            await MainActor.run {
                self.transactions = userTransactions.sorted(by: { $0.timestamp > $1.timestamp })
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = VizionAppError.from(error)
                self.isLoading = false
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            // Transaction icon based on type
            ZStack {
                Circle()
                    .fill(transaction.status == .completed ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .foregroundColor(transaction.status == .completed ? .green : .orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.transactionDescription ?? "Transaction")
                    .font(.headline)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
                
                Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount)
                    .font(.headline)
                    .foregroundColor(transaction.type == .refund ? .green : .primary)
                
                Text(transaction.status.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency
        let decimalNumber = NSDecimalNumber(decimal: transaction.amount)
        return formatter.string(from: decimalNumber) ?? "$\(transaction.amount)"
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transaction.timestamp)
    }
    
    private var iconName: String {
        switch transaction.type {
        case .payment:
            return "arrow.up.circle.fill"
        case .refund:
            return "arrow.down.circle.fill"
        case .payout:
            return "banknote.fill"
        case .fee:
            return "percent"
        case .chargeback:
            return "arrow.uturn.down.circle.fill"
        case .adjustment:
            return "arrow.left.arrow.right.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch transaction.status {
        case .completed:
            return .green
        case .pending:
            return .orange
        case .failed:
            return .red
        case .refunded:
            return .blue
        case .disputed:
            return .purple
        case .processing:
            return .blue
        case .cancelled:
            return .gray
        }
    }
}

