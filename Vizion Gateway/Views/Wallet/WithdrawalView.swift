import SwiftUI
import SwiftData
import Combine

struct WithdrawalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // User data
    private let userId: String
    private let walletType: WalletType
    private let onComplete: () -> Void
    
    // Form data
    @State private var selectedCurrency: Currency = .xcd
    @State private var amount: Double = 0
    @State private var destinationType: WithdrawalDestination = .bankAccount
    @State private var bankName: String = ""
    @State private var accountNumber: String = ""
    @State private var accountName: String = ""
    @State private var routingNumber: String = ""
    
    // Form validation and state
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var wallet: Wallet?
    @State private var showingConfirmation = false
    @State private var showingSuccess = false
    
    // Timer for managing state
    @State private var timer: Timer.TimerPublisher = Timer.publish(every: 1, on: .main, in: .common)
    @State private var timerSubscription: Cancellable?
    
    init(userId: String, walletType: WalletType, onComplete: @escaping () -> Void) {
        self.userId = userId
        self.walletType = walletType
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Loading state
                if isLoading {
                    ProgressView("Processing withdrawal...")
                } else if showingSuccess {
                    // Success state
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                        
                        Text("Withdrawal Request Submitted")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Your withdrawal request for \(amount.formatted(.currency(code: selectedCurrency.rawValue))) has been submitted for processing.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Done") {
                            onComplete()
                            dismiss()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.top, 16)
                    }
                    .padding()
                } else {
                    // Form view
                    Form {
                        // Balance section
                        if let wallet = wallet {
                            Section("Available Balance") {
                                ForEach(wallet.balances.map(\.currency), id: \.self) { currency in
                                    HStack {
                                        Text(currency.rawValue)
                                        Spacer()
                                        Text(wallet.availableBalance(for: currency).formatted(.currency(code: currency.rawValue)))
                                            .fontWeight(.semibold)
                                            .foregroundColor(wallet.availableBalance(for: currency) > 0 ? .primary : .secondary)
                                    }
                                }
                                
                                if wallet.balances.isEmpty {
                                    Text("No funds available for withdrawal")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Withdrawal details
                        Section("Withdrawal Details") {
                            Picker("Currency", selection: $selectedCurrency) {
                                ForEach(Currency.allCases, id: \.self) { currency in
                                    Text(currency.rawValue).tag(currency)
                                }
                            }
                            .pickerStyle(.menu)
                            
                            HStack {
                                Text("Amount")
                                Spacer()
                                TextField("0.00", value: $amount, format: .currency(code: selectedCurrency.rawValue))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .focused($isAmountFocused)
                            }
                            
                            if let wallet = wallet {
                                let maxAmount = wallet.availableBalance(for: selectedCurrency)
                                
                                Button("Withdraw Maximum: \(maxAmount.formatted(.currency(code: selectedCurrency.rawValue)))") {
                                    amount = maxAmount
                                }
                                .disabled(maxAmount <= 0)
                                .foregroundColor(maxAmount > 0 ? .blue : .secondary)
                            }
                            
                            Picker("Destination", selection: $destinationType) {
                                Text("Bank Account").tag(WithdrawalDestination.bankAccount)
                                Text("Card").tag(WithdrawalDestination.card)
                                Text("External Wallet").tag(WithdrawalDestination.wallet)
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Bank account details
                        if destinationType == .bankAccount {
                            Section("Bank Account Details") {
                                TextField("Bank Name", text: $bankName)
                                    .autocapitalization(.words)
                                
                                TextField("Account Name", text: $accountName)
                                    .autocapitalization(.words)
                                
                                TextField("Account Number", text: $accountNumber)
                                    .keyboardType(.numberPad)
                                
                                TextField("Routing Number", text: $routingNumber)
                                    .keyboardType(.numberPad)
                            }
                        }
                        
                        // Card details
                        if destinationType == .card {
                            Section("Card Details") {
                                Text("Card withdrawals are not currently supported.")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Wallet details
                        if destinationType == .wallet {
                            Section("External Wallet") {
                                Text("External wallet withdrawals are not currently supported.")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Withdrawal information
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Important Information")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text("• Withdrawals are processed within 1-3 business days")
                                    .font(.caption)
                                
                                Text("• Minimum withdrawal amount: 10.00 \(selectedCurrency.rawValue)")
                                    .font(.caption)
                                
                                Text("• A processing fee may apply depending on your withdrawal method")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        // Submit button
                        Section {
                            Button("Request Withdrawal") {
                                submitWithdrawal()
                            }
                            .frame(maxWidth: .infinity)
                            .disabled(!isFormValid)
                        }
                    }
                    .alert("Error", isPresented: $showingError) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(errorMessage)
                    }
                    .confirmationDialog(
                        "Confirm Withdrawal",
                        isPresented: $showingConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Yes, request withdrawal", role: .destructive) {
                            processWithdrawal()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to withdraw \(amount.formatted(.currency(code: selectedCurrency.rawValue)))?")
                    }
                }
            }
            .navigationTitle("Withdraw Funds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isLoading && !showingSuccess {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await loadWalletData()
            }
        }
    }
    
    private var isFormValid: Bool {
        guard amount >= 10 else { return false }
        
        guard let wallet = wallet, wallet.availableBalance(for: selectedCurrency) >= amount else {
            return false
        }
        
        switch destinationType {
        case .bankAccount:
            return !bankName.isEmpty && !accountNumber.isEmpty && !accountName.isEmpty && !routingNumber.isEmpty
        case .card, .wallet:
            return false // Not supported yet
        }
    }
    
    private func loadWalletData() async {
        isLoading = true
        
        do {
            wallet = try await WalletManager.shared.getWallet(for: userId, type: walletType)
        } catch {
            errorMessage = "Failed to load wallet: \(error.localizedDescription)"
            showingError = true
        }
        
        isLoading = false
    }
    
    private func submitWithdrawal() {
        // Ensure we have a valid wallet and amount
        guard let wallet = wallet, wallet.availableBalance(for: selectedCurrency) >= amount else {
            errorMessage = "Insufficient funds for withdrawal"
            showingError = true
            return
        }
        
        guard amount >= 10 else {
            errorMessage = "Minimum withdrawal amount is 10.00 \(selectedCurrency.rawValue)"
            showingError = true
            return
        }
        
        // Show confirmation dialog
        showingConfirmation = true
    }
    
    private func processWithdrawal() {
        isLoading = true
        
        // Create destination details based on withdrawal type
        var destinationDetails: [String: String] = [:]
        
        switch destinationType {
        case .bankAccount:
            destinationDetails = [
                "bankName": bankName,
                "accountName": accountName,
                "accountNumber": accountNumber,
                "routingNumber": routingNumber,
                "accountId": "\(bankName)-\(accountNumber)" // Used as an ID for transactions
            ]
        case .card:
            // Not implemented
            destinationDetails = ["type": "card"]
        case .wallet:
            // Not implemented
            destinationDetails = ["type": "wallet"]
        }
        
        // Submit the withdrawal request
        Task {
            do {
                let request = try await WalletManager.shared.createWithdrawalRequest(
                    userId: userId,
                    amount: amount,
                    currency: selectedCurrency,
                    destinationType: destinationType,
                    destinationDetails: destinationDetails
                )
                
                print("Withdrawal request created: \(request.id)")
                
                // Show success view
                await MainActor.run {
                    isLoading = false
                    showingSuccess = true
                    
                    // Start a timer to dismiss after a few seconds
                    timer = Timer.publish(every: 5, on: .main, in: .common)
                    timerSubscription = timer
                        .autoconnect()
                        .sink { _ in
                            onComplete()
                            dismiss()
                        }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to create withdrawal request: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - Focus State
    
    @FocusState private var isAmountFocused: Bool
}

// MARK: - Preview

#Preview {
    WithdrawalView(
        userId: "preview_user",
        walletType: .user,
        onComplete: {}
    )
} 