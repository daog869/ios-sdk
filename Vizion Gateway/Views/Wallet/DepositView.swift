import SwiftUI
import SwiftData
import Combine

struct DepositView: View {
    @Environment(\.dismiss) private var dismiss
    
    // User data
    private let userId: String
    private let walletType: WalletType
    private let onComplete: () -> Void
    
    // Form data
    @State private var selectedCurrency: Currency = .xcd
    @State private var amount: Double = 0
    @State private var depositMethod: DepositMethod = .card
    @State private var cardNumber: String = ""
    @State private var cardExpiry: String = ""
    @State private var cardCVV: String = ""
    @State private var cardName: String = ""
    @State private var bankName: String = ""
    @State private var accountNumber: String = ""
    @State private var reference: String = "Wallet Deposit"
    
    // Form validation and state
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
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
                    ProgressView("Processing deposit...")
                } else if showingSuccess {
                    // Success state
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                        
                        Text("Deposit Successful")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Your deposit of \(amount.formatted(.currency(code: selectedCurrency.rawValue))) has been processed successfully.")
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
                        // Deposit details
                        Section("Deposit Details") {
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
                            
                            // Quick amount buttons
                            HStack {
                                ForEach([50.0, 100.0, 200.0, 500.0], id: \.self) { value in
                                    Button(value.formatted(.currency(code: selectedCurrency.rawValue, dropDecimals: true))) {
                                        amount = value
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            
                            Picker("Deposit Method", selection: $depositMethod) {
                                Text("Credit/Debit Card").tag(DepositMethod.card)
                                Text("Bank Transfer").tag(DepositMethod.bank)
                                if walletType == .merchant {
                                    Text("Payment Link").tag(DepositMethod.paymentLink)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Payment method details
                        switch depositMethod {
                        case .card:
                            Section("Card Details") {
                                TextField("Card Number", text: $cardNumber)
                                    .keyboardType(.numberPad)
                                    .onChange(of: cardNumber) { newValue in
                                        cardNumber = formatCardNumber(newValue)
                                    }
                                
                                HStack {
                                    TextField("MM/YY", text: $cardExpiry)
                                        .keyboardType(.numberPad)
                                        .onChange(of: cardExpiry) { newValue in
                                            cardExpiry = formatExpiryDate(newValue)
                                        }
                                    
                                    Spacer()
                                    
                                    TextField("CVV", text: $cardCVV)
                                        .keyboardType(.numberPad)
                                        .frame(width: 60)
                                        .multilineTextAlignment(.center)
                                        .onChange(of: cardCVV) { newValue in
                                            cardCVV = String(newValue.prefix(3))
                                        }
                                }
                                
                                TextField("Name on Card", text: $cardName)
                                    .autocapitalization(.words)
                            }
                            
                        case .bank:
                            Section("Bank Transfer") {
                                TextField("Bank Name", text: $bankName)
                                    .autocapitalization(.words)
                                
                                TextField("Account Number", text: $accountNumber)
                                    .keyboardType(.numberPad)
                                
                                TextField("Reference", text: $reference)
                            }
                            
                        case .paymentLink:
                            Section("Payment Link") {
                                Text("A payment link will be generated that you can share with customers.")
                                    .foregroundColor(.secondary)
                                
                                TextField("Reference", text: $reference)
                            }
                        }
                        
                        // Deposit information
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Important Information")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text("• Card deposits are processed immediately")
                                    .font(.caption)
                                
                                Text("• Bank transfers may take 1-3 business days to process")
                                    .font(.caption)
                                
                                Text("• Minimum deposit amount: 10.00 \(selectedCurrency.rawValue)")
                                    .font(.caption)
                                
                                Text("• A processing fee may apply depending on your deposit method")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        // Submit button
                        Section {
                            Button("Deposit Now") {
                                submitDeposit()
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
                        "Confirm Deposit",
                        isPresented: $showingConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Yes, deposit funds", role: .none) {
                            processDeposit()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to deposit \(amount.formatted(.currency(code: selectedCurrency.rawValue)))?")
                    }
                }
            }
            .navigationTitle("Deposit Funds")
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
        }
    }
    
    private var isFormValid: Bool {
        guard amount >= 10 else { return false }
        
        switch depositMethod {
        case .card:
            return cardNumber.count >= 16 && cardExpiry.count == 5 && cardCVV.count == 3 && !cardName.isEmpty
        case .bank:
            return !bankName.isEmpty && !accountNumber.isEmpty && !reference.isEmpty
        case .paymentLink:
            return !reference.isEmpty
        }
    }
    
    private func submitDeposit() {
        // Validate amount
        guard amount >= 10 else {
            errorMessage = "Minimum deposit amount is 10.00 \(selectedCurrency.rawValue)"
            showingError = true
            return
        }
        
        // Further validation based on deposit method
        switch depositMethod {
        case .card:
            if cardNumber.count < 16 {
                errorMessage = "Please enter a valid card number"
                showingError = true
                return
            }
            
            if cardExpiry.count < 5 {
                errorMessage = "Please enter a valid expiry date (MM/YY)"
                showingError = true
                return
            }
            
            if cardCVV.count < 3 {
                errorMessage = "Please enter a valid CVV"
                showingError = true
                return
            }
            
            if cardName.isEmpty {
                errorMessage = "Please enter the name on the card"
                showingError = true
                return
            }
            
        case .bank:
            if bankName.isEmpty || accountNumber.isEmpty {
                errorMessage = "Please enter valid bank details"
                showingError = true
                return
            }
            
        case .paymentLink:
            if reference.isEmpty {
                errorMessage = "Please enter a reference for this payment link"
                showingError = true
                return
            }
        }
        
        // Show confirmation dialog
        showingConfirmation = true
    }
    
    private func processDeposit() {
        isLoading = true
        
        // Create metadata for the deposit
        var metadata: [String: String] = [
            "method": depositMethod.rawValue,
            "reference": reference
        ]
        
        switch depositMethod {
        case .card:
            metadata["cardLast4"] = String(cardNumber.suffix(4))
        case .bank:
            metadata["bankName"] = bankName
            metadata["accountNumberLast4"] = String(accountNumber.suffix(4))
        case .paymentLink:
            metadata["paymentLinkId"] = UUID().uuidString
        }
        
        // Description for the transaction
        let description: String
        switch depositMethod {
        case .card:
            description = "Card deposit (\(cardNumber.suffix(4)))"
        case .bank:
            description = "Bank transfer from \(bankName)"
        case .paymentLink:
            description = "Payment link deposit"
        }
        
        // Submit the deposit
        Task {
            do {
                // Convert EntityType from walletType
                let entityType: EntityType = walletType == .user ? .user : .merchant
                
                // Process the deposit through WalletManager
                let transaction = try await WalletManager.shared.processDeposit(
                    amount: amount,
                    currency: selectedCurrency,
                    destinationId: userId,
                    destinationType: entityType,
                    reference: reference,
                    description: description,
                    metadata: metadata
                )
                
                print("Deposit processed: \(transaction.id)")
                
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
                    errorMessage = "Failed to process deposit: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatCardNumber(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        let limited = String(cleaned.prefix(16))
        
        // Format with spaces
        var formatted = ""
        for (index, character) in limited.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted.append(character)
        }
        
        return formatted
    }
    
    private func formatExpiryDate(_ date: String) -> String {
        let cleaned = date.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        let limited = String(cleaned.prefix(4))
        
        if limited.count > 2 {
            let month = limited.prefix(2)
            let year = limited.suffix(limited.count - 2)
            return "\(month)/\(year)"
        }
        
        return limited
    }
    
    // MARK: - Focus State
    
    @FocusState private var isAmountFocused: Bool
}

// MARK: - Supporting Types

enum DepositMethod: String, CaseIterable {
    case card = "card"
    case bank = "bank"
    case paymentLink = "payment_link"
}

// MARK: - Currency Format Extensions

extension FormatStyle where Self == FloatingPointFormatStyle<Double>.Currency {
    static func currency(code: String, dropDecimals: Bool = false) -> Self {
        let formatter = FloatingPointFormatStyle<Double>.Currency(code: code)
        if dropDecimals {
            return formatter.precision(.fractionLength(0))
        }
        return formatter
    }
}

// MARK: - Preview

#Preview {
    DepositView(
        userId: "preview_user",
        walletType: .user,
        onComplete: {}
    )
} 