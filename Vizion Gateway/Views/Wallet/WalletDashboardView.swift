import SwiftUI
import SwiftData
import Combine
import FirebaseAuth

struct WalletDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    // User data
    private let userId: String
    private let walletType: WalletType
    
    // State
    @State private var wallet: Wallet?
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedCurrency: Currency = .xcd
    @State private var recentTransactions: [WalletTransaction] = []
    @State private var showingDepositSheet = false
    @State private var showingWithdrawalSheet = false
    @State private var showingTransferSheet = false
    @State private var showingAllTransactions = false
    
    // For balance notifications
    @State private var showBalanceNotification = false
    @State private var balanceNotificationText = ""
    @State private var cancellables = Set<AnyCancellable>()
    
    init(userId: String, walletType: WalletType = .user) {
        self.userId = userId
        self.walletType = walletType
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Loading wallet...")
                } else if let wallet = wallet {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Balance Cards
                            BalanceCardsView(
                                wallet: wallet,
                                selectedCurrency: $selectedCurrency
                            )
                            
                            // Quick Actions
                            WalletQuickActionsView(
                                onDeposit: { showingDepositSheet = true },
                                onWithdraw: { showingWithdrawalSheet = true },
                                onTransfer: { showingTransferSheet = true }
                            )
                            
                            // Recent Transactions
                            WalletTransactionsSummaryView(
                                transactions: recentTransactions,
                                onViewAll: { showingAllTransactions = true }
                            )
                            
                            // Reserve Information (for merchants)
                            if walletType == .merchant {
                                ReserveInfoView(wallet: wallet, selectedCurrency: selectedCurrency)
                            }
                            
                            // Settlement Information (for merchants)
                            if walletType == .merchant && wallet.autoSettlement, let nextDate = wallet.nextSettlementDate {
                                SettlementInfoView(
                                    settlementFrequency: wallet.settlementFrequency,
                                    nextSettlementDate: nextDate
                                )
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await loadWalletData()
                    }
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Error Loading Wallet")
                            .font(.headline)
                        
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Try Again") {
                            Task {
                                await loadWalletData()
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "wallet.pass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Wallet Found")
                            .font(.headline)
                        
                        Text("Create a wallet to start managing your funds")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Create Wallet") {
                            Task {
                                await createWallet()
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                }
            }
            .navigationTitle("Wallet")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await loadWalletData()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingDepositSheet) {
                DepositView(userId: userId, walletType: walletType, onComplete: {
                    Task {
                        await loadWalletData()
                    }
                })
            }
            .sheet(isPresented: $showingWithdrawalSheet) {
                WithdrawalView(userId: userId, walletType: walletType, onComplete: {
                    Task {
                        await loadWalletData()
                    }
                })
            }
            .sheet(isPresented: $showingTransferSheet) {
                TransferView(userId: userId, walletType: walletType, onComplete: {
                    Task {
                        await loadWalletData()
                    }
                })
            }
            .navigationDestination(isPresented: $showingAllTransactions) {
                TransactionListView(userId: userId, walletType: walletType)
            }
            .overlay(alignment: .bottom) {
                if showBalanceNotification {
                    Text(balanceNotificationText)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                withAnimation {
                                    showBalanceNotification = false
                                }
                            }
                        }
                }
            }
        }
        .task {
            await loadWalletData()
            setupBalanceChangeListener()
        }
    }
    
    private func loadWalletData() async {
        isLoading = true
        error = nil
        
        do {
            // Get wallet
            wallet = try await WalletManager.shared.getWallet(for: userId, type: walletType)
            
            // If no wallet exists, create one
            if wallet == nil {
                await createWallet()
            }
            
            // Get recent transactions
            if let wallet = wallet {
                // Since we're having issues with predicates, let's use our fallback approach directly
                do {
                    // Fetch all transactions without filtering by complex relationship
                    var allTransactionsDescriptor = FetchDescriptor<WalletTransaction>(
                        sortBy: [SortDescriptor(\WalletTransaction.createdAt, order: .reverse)]
                    )
                    
                    let allTransactions = try modelContext.fetch(allTransactionsDescriptor)
                    
                    // Filter in memory
                    recentTransactions = allTransactions
                        .filter { transaction in transaction.wallet?.id == wallet.id }
                        .prefix(5)
                        .map { $0 }
                } catch {
                    self.error = "Error fetching transactions: \(error.localizedDescription)"
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func createWallet() async {
        do {
            wallet = try await WalletManager.shared.createWallet(for: userId, type: walletType)
        } catch {
            self.error = "Failed to create wallet: \(error.localizedDescription)"
        }
    }
    
    private func setupBalanceChangeListener() {
        WalletManager.shared.balanceChangePublisher
            .filter { notification in notification.userId == userId && notification.walletType == walletType }
            .receive(on: DispatchQueue.main)
            .sink { notification in
                // Show notification
                let formattedAmount = abs(notification.amountChanged).formatted(.currency(code: notification.currency.rawValue))
                
                if notification.amountChanged > 0 {
                    balanceNotificationText = "Added \(formattedAmount) to your wallet"
                } else {
                    balanceNotificationText = "Removed \(formattedAmount) from your wallet"
                }
                
                withAnimation {
                    showBalanceNotification = true
                }
                
                // Refresh wallet data
                Task {
                    await loadWalletData()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Views

struct BalanceCardsView: View {
    let wallet: Wallet
    @Binding var selectedCurrency: Currency
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Balance")
                .font(.headline)
                .foregroundColor(.secondary)
            
            TabView(selection: $selectedCurrency) {
                ForEach(wallet.balances.isEmpty ? [Currency.xcd] : wallet.balances.map(\.currency), id: \.self) { currency in
                    BalanceCardView(
                        totalBalance: wallet.balance(for: currency),
                        availableBalance: wallet.availableBalance(for: currency),
                        reserveAmount: wallet.reserve(for: currency),
                        currency: currency
                    )
                    .tag(currency)
                }
            }
            .frame(height: 200)
            .tabViewStyle(.page(indexDisplayMode: .always))
            
            // Currency picker for empty balances
            if wallet.balances.count < Currency.allCases.count {
                Menu {
                    ForEach(Currency.allCases.filter { currency in
                        !wallet.balances.contains { $0.currency == currency }
                    }, id: \.self) { currency in
                        Button(currency.rawValue) {
                            selectedCurrency = currency
                        }
                    }
                } label: {
                    Label("Add Currency", systemImage: "plus.circle")
                        .font(.subheadline)
                }
            }
        }
    }
}

struct BalanceCardView: View {
    let totalBalance: Double
    let availableBalance: Double
    let reserveAmount: Double
    let currency: Currency
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(currency.rawValue)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    Image(systemName: currencyIcon(for: currency))
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                Text(totalBalance.formatted(.currency(code: currency.rawValue)))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Available")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(availableBalance.formatted(.currency(code: currency.rawValue)))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    if reserveAmount > 0 {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Reserved")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(reserveAmount.formatted(.currency(code: currency.rawValue)))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
            .padding()
        }
        .frame(height: 180)
        .padding(.horizontal)
    }
    
    private func currencyIcon(for currency: Currency) -> String {
        switch currency {
        case .xcd: return "dollarsign.circle"
        case .usd: return "dollarsign.circle"
        case .eur: return "eurosign.circle"
        case .gbp: return "sterlingsign.circle"
        }
    }
}

struct WalletQuickActionsView: View {
    let onDeposit: () -> Void
    let onWithdraw: () -> Void
    let onTransfer: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                WalletActionButton(
                    title: "Deposit",
                    systemImage: "arrow.down.circle.fill",
                    color: .green,
                    action: onDeposit
                )
                
                WalletActionButton(
                    title: "Withdraw",
                    systemImage: "arrow.up.circle.fill",
                    color: .orange,
                    action: onWithdraw
                )
                
                WalletActionButton(
                    title: "Transfer",
                    systemImage: "arrow.left.arrow.right.circle.fill",
                    color: .blue,
                    action: onTransfer
                )
            }
        }
    }
}

struct WalletActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

struct WalletTransactionsSummaryView: View {
    let transactions: [WalletTransaction]
    let onViewAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("View All", action: onViewAll)
                    .font(.subheadline)
            }
            
            if transactions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        
                        Text("No transactions yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
            } else {
                ForEach(transactions) { transaction in
                    WalletTransactionRowView(transaction: transaction)
                }
            }
        }
    }
}

struct WalletTransactionRowView: View {
    let transaction: WalletTransaction
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: iconName(for: transaction.type))
                .font(.title2)
                .foregroundColor(color(for: transaction.type))
                .frame(width: 40, height: 40)
                .background(color(for: transaction.type).opacity(0.1))
                .cornerRadius(20)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(title(for: transaction))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(transaction.createdAt.formatted(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount(for: transaction))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(amountColor(for: transaction))
                
                Text(transaction.currency.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
    
    private func iconName(for type: WalletTransactionType) -> String {
        switch type {
        case .deposit: return "arrow.down.circle"
        case .withdrawal: return "arrow.up.circle"
        case .payment: return "creditcard"
        case .refund: return "arrow.counterclockwise.circle"
        case .chargeback: return "exclamationmark.triangle"
        case .fee: return "percent"
        case .transfer: return "arrow.left.arrow.right"
        case .settlement: return "building.columns"
        case .reserveRelease: return "lock.open"
        }
    }
    
    private func color(for type: WalletTransactionType) -> Color {
        switch type {
        case .deposit, .refund, .reserveRelease: return .green
        case .withdrawal, .payment, .fee, .settlement: return .orange
        case .chargeback: return .red
        case .transfer: return .blue
        }
    }
    
    private func title(for transaction: WalletTransaction) -> String {
        switch transaction.type {
        case .deposit: return "Deposit"
        case .withdrawal: return "Withdrawal"
        case .payment: return transaction.transactionDescription ?? "Payment"
        case .refund: return "Refund"
        case .chargeback: return "Chargeback"
        case .fee: return "Fee"
        case .transfer: return "Transfer"
        case .settlement: return "Settlement"
        case .reserveRelease: return "Reserve Release"
        }
    }
    
    private func formattedAmount(for transaction: WalletTransaction) -> String {
        let prefix: String
        
        switch transaction.type {
        case .deposit, .refund, .reserveRelease:
            prefix = "+"
        case .withdrawal, .payment, .fee, .chargeback, .settlement:
            prefix = "-"
        case .transfer:
            // For transfers, check if the user is the source or destination
            if transaction.destinationType == .user {
                prefix = "+"
            } else {
                prefix = "-"
            }
        }
        
        return "\(prefix)\(transaction.amount.formatted(.currency(code: transaction.currency.rawValue)))"
    }
    
    private func amountColor(for transaction: WalletTransaction) -> Color {
        switch transaction.type {
        case .deposit, .refund, .reserveRelease:
            return .green
        case .withdrawal, .payment, .fee, .chargeback, .settlement:
            return .red
        case .transfer:
            // For transfers, check if the user is the source or destination
            if transaction.destinationType == .user {
                return .green
            } else {
                return .red
            }
        }
    }
}

struct ReserveInfoView: View {
    let wallet: Wallet
    let selectedCurrency: Currency
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Merchant Reserve")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reserve Rate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(wallet.reservePercentage * 100))%")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Current Reserve")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(wallet.reserve(for: selectedCurrency).formatted(.currency(code: selectedCurrency.rawValue)))
                            .font(.headline)
                    }
                }
                
                Text("Reserves are held to protect against chargebacks and disputes. They are typically released after 90 days.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

struct SettlementInfoView: View {
    let settlementFrequency: SettlementFrequency
    let nextSettlementDate: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settlements")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Frequency")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(frequencyText(for: settlementFrequency))
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Next Settlement")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(nextSettlementDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.headline)
                    }
                }
                
                Text("Available funds will be automatically transferred to your bank account on the settlement date.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    private func frequencyText(for frequency: SettlementFrequency) -> String {
        switch frequency {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .monthly: return "Monthly"
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationView {
        WalletDashboardView(userId: "preview_user")
    }
} 
