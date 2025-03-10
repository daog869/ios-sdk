import SwiftUI
import SwiftData
import Combine
import FirebaseAuth

struct TransferView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // User data
    private let userId: String
    private let walletType: WalletType
    private let onComplete: () -> Void
    
    // Form data
    @State private var selectedCurrency: Currency = .xcd
    @State private var amount: Double = 0
    @State private var destinationType: EntityType = .user
    @State private var destinationId: String = ""
    @State private var description: String = "Wallet Transfer"
    
    // Form validation and state
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var wallet: Wallet?
    @State private var showingConfirmation = false
    @State private var showingSuccess = false
    @State private var showingRecipientSearch = false
    @State private var searchResults: [UserSearchResult] = []
    @State private var searchText = ""
    
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
                    ProgressView("Processing transfer...")
                } else if showingSuccess {
                    // Success state
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                        
                        Text("Transfer Successful")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Your transfer of \(amount.formatted(.currency(code: selectedCurrency.rawValue))) has been processed successfully.")
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
                                    Text("No funds available for transfer")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Transfer details
                        Section("Transfer Details") {
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
                                
                                Button("Transfer Maximum: \(maxAmount.formatted(.currency(code: selectedCurrency.rawValue)))") {
                                    amount = maxAmount
                                }
                                .disabled(maxAmount <= 0)
                                .foregroundColor(maxAmount > 0 ? .blue : .secondary)
                            }
                            
                            Picker("Recipient Type", selection: $destinationType) {
                                Text("User").tag(EntityType.user)
                                Text("Merchant").tag(EntityType.merchant)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: destinationType) { _ in
                                // Reset destination ID when switching types
                                destinationId = ""
                            }
                            
                            Button(action: {
                                showingRecipientSearch = true
                            }) {
                                HStack {
                                    Text("Select Recipient")
                                    Spacer()
                                    if !destinationId.isEmpty {
                                        Text(formatRecipientName())
                                            .foregroundColor(.secondary)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            TextField("Description", text: $description)
                        }
                        
                        // Transfer information
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Important Information")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text("• Transfers are processed immediately")
                                    .font(.caption)
                                
                                Text("• Minimum transfer amount: 10.00 \(selectedCurrency.rawValue)")
                                    .font(.caption)
                                
                                Text("• You cannot transfer more than your available balance")
                                    .font(.caption)
                                
                                Text("• The recipient must have an account in the selected currency")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        // Submit button
                        Section {
                            Button("Transfer Now") {
                                submitTransfer()
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
                        "Confirm Transfer",
                        isPresented: $showingConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Yes, transfer funds", role: .destructive) {
                            processTransfer()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to transfer \(amount.formatted(.currency(code: selectedCurrency.rawValue))) to \(formatRecipientName())?")
                    }
                    .sheet(isPresented: $showingRecipientSearch) {
                        RecipientSearchView(entityType: destinationType) { result in
                            destinationId = result.id
                            showingRecipientSearch = false
                        }
                    }
                }
            }
            .navigationTitle("Transfer Funds")
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
        
        return !destinationId.isEmpty && userId != destinationId
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
    
    private func formatRecipientName() -> String {
        // In a real app, you would load the recipient's name from a database
        // For now, we'll just show the ID
        let idSuffix = String(destinationId.suffix(6))
        return "\(destinationType.rawValue.capitalized) (\(idSuffix))"
    }
    
    private func submitTransfer() {
        // Ensure we have a valid wallet and amount
        guard let wallet = wallet, wallet.availableBalance(for: selectedCurrency) >= amount else {
            errorMessage = "Insufficient funds for transfer"
            showingError = true
            return
        }
        
        guard amount >= 10 else {
            errorMessage = "Minimum transfer amount is 10.00 \(selectedCurrency.rawValue)"
            showingError = true
            return
        }
        
        guard !destinationId.isEmpty else {
            errorMessage = "Please select a recipient"
            showingError = true
            return
        }
        
        guard userId != destinationId else {
            errorMessage = "You cannot transfer funds to yourself"
            showingError = true
            return
        }
        
        // Show confirmation dialog
        showingConfirmation = true
    }
    
    private func processTransfer() {
        isLoading = true
        
        // Create a description if the user didn't provide one
        let transferDescription = description.isEmpty ? "Transfer to \(formatRecipientName())" : description
        
        // Transfer metadata
        let metadata: [String: String] = [
            "initiatorType": walletType.rawValue,
            "initiatorId": userId,
            "transferType": "wallet_to_wallet"
        ]
        
        // Convert WalletType to EntityType
        let sourceType: EntityType = walletType == .user ? .user : .merchant
        
        // Submit the transfer
        Task {
            do {
                // Process the transfer using WalletManager
                let transaction = try await WalletManager.shared.processPayment(
                    amount: amount,
                    currency: selectedCurrency,
                    sourceId: userId,
                    sourceType: sourceType,
                    destinationId: destinationId,
                    destinationType: destinationType,
                    reference: UUID().uuidString,
                    description: transferDescription,
                    metadata: metadata
                )
                
                print("Transfer processed: \(transaction.id)")
                
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
                    errorMessage = "Failed to process transfer: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - Focus State
    
    @FocusState private var isAmountFocused: Bool
}

// MARK: - Recipient Search

struct RecipientSearchView: View {
    @Environment(\.dismiss) private var dismiss
    
    let entityType: EntityType
    let onSelect: (UserSearchResult) -> Void
    
    @State private var searchText = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search by name or email", text: $searchText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Results
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty {
                    if !searchText.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No matching \(entityType.rawValue)s found")
                                .font(.headline)
                            
                            Text("Try a different search term or invite them to join")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "person.3")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("Search for a \(entityType.rawValue)")
                                .font(.headline)
                            
                            Text("Enter a name or email to find recipients")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    List {
                        ForEach(searchResults) { result in
                            Button {
                                onSelect(result)
                            } label: {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.name)
                                            .fontWeight(.medium)
                                        
                                        Text(result.email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Recipient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // In a real app, you would search for users in your database
        // For this example, we'll simulate a search with some fake data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let demoUsers: [UserSearchResult] = [
                UserSearchResult(id: "user1", name: "John Smith", email: "john.smith@example.com", type: .user),
                UserSearchResult(id: "user2", name: "Jane Doe", email: "jane.doe@example.com", type: .user),
                UserSearchResult(id: "merchant1", name: "Coffee Shop", email: "shop@coffeeshop.com", type: .merchant),
                UserSearchResult(id: "merchant2", name: "Book Store", email: "sales@bookstore.com", type: .merchant)
            ]
            
            // Filter by text and entity type
            searchResults = demoUsers.filter { result in
                result.type == (entityType == .user ? .user : .merchant) &&
                (result.name.localizedCaseInsensitiveContains(searchText) ||
                 result.email.localizedCaseInsensitiveContains(searchText))
            }
            
            isSearching = false
        }
    }
}

// MARK: - Supporting Types

struct UserSearchResult: Identifiable {
    let id: String
    let name: String
    let email: String
    let type: WalletType
}

// MARK: - Preview

#Preview {
    TransferView(
        userId: "preview_user",
        walletType: .user,
        onComplete: {}
    )
} 