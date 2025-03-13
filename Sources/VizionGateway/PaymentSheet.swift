import SwiftUI
import PassKit

/// A payment sheet that handles different payment methods
public struct PaymentSheet: View {
    // MARK: - Properties
    
    /// The available payment methods
    public enum PaymentOption: String, Identifiable, CaseIterable {
        /// Credit or debit card
        case card
        
        /// Apple Pay
        case applePay
        
        /// Bank transfer
        case bankTransfer
        
        public var id: String { rawValue }
        
        /// Display name for the payment method
        public var displayName: String {
            switch self {
            case .card:
                return "Credit or Debit Card"
            case .applePay:
                return "Apple Pay"
            case .bankTransfer:
                return "Bank Transfer"
            }
        }
        
        /// Icon name for the payment method
        public var iconName: String {
            switch self {
            case .card:
                return "creditcard"
            case .applePay:
                return "apple.logo"
            case .bankTransfer:
                return "building.columns"
            }
        }
    }
    
    @State private var selectedOption: PaymentOption = .card
    @State private var showCardPayment = false
    @State private var showBankTransfer = false
    @State private var isApplePayProcessing = false
    @Environment(\.dismiss) private var dismiss
    
    /// Payment completion callback
    public var onPaymentComplete: (PaymentResult) -> Void
    
    // Payment details
    private let amount: Decimal
    private let currency: Currency
    private let sourceId: String
    private let destinationId: String
    private let orderId: String
    
    /// Initial payment option to select
    private let initialOption: PaymentOption
    
    // MARK: - Initialization
    
    /// Initialize the payment sheet
    /// - Parameters:
    ///   - amount: The payment amount
    ///   - currency: The payment currency
    ///   - sourceId: ID of the source account or customer
    ///   - destinationId: ID of the destination account or merchant
    ///   - orderId: The order ID associated with this payment
    ///   - initialOption: The initial payment method to select
    ///   - onPaymentComplete: Callback for payment completion
    public init(
        amount: Decimal,
        currency: Currency = .xcd,
        sourceId: String,
        destinationId: String,
        orderId: String,
        initialOption: PaymentOption = .card,
        onPaymentComplete: @escaping (PaymentResult) -> Void
    ) {
        self.amount = amount
        self.currency = currency
        self.sourceId = sourceId
        self.destinationId = destinationId
        self.orderId = orderId
        self.initialOption = initialOption
        self.onPaymentComplete = onPaymentComplete
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Amount display
                amountView
                
                // Payment method selector
                paymentMethodSelector
                
                Spacer()
                
                // Pay button
                paymentButton
            }
            .padding()
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCardPayment) {
                CardPaymentView(
                    amount: amount,
                    currency: currency,
                    sourceId: sourceId,
                    destinationId: destinationId,
                    orderId: orderId,
                    onPaymentComplete: handlePaymentComplete
                )
            }
        }
        .onAppear {
            // Set the initial payment option
            selectedOption = initialOption
        }
    }
    
    // MARK: - Subviews
    
    /// View displaying the payment amount
    private var amountView: some View {
        VStack(spacing: 8) {
            Text("Total Amount")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("\(currencySymbol)\(amount, format: .number.precision(.fractionLength(2)))")
                .font(.system(size: 36, weight: .bold))
        }
        .padding(.top)
    }
    
    /// Payment method selection view
    private var paymentMethodSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Payment Method")
                .font(.headline)
            
            ForEach(PaymentOption.allCases) { option in
                Button {
                    selectedOption = option
                } label: {
                    HStack {
                        Image(systemName: option.iconName)
                            .font(.title3)
                            .frame(width: 30)
                        
                        Text(option.displayName)
                            .font(.body)
                        
                        Spacer()
                        
                        if selectedOption == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                selectedOption == option ? Color.accentColor : Color.secondary.opacity(0.3),
                                lineWidth: selectedOption == option ? 2 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
                
                // Hide Apple Pay if not available
                .opacity(option == .applePay && !isApplePayAvailable ? 0.5 : 1)
                .disabled(option == .applePay && !isApplePayAvailable)
            }
            
            if selectedOption == .applePay && !isApplePayAvailable {
                Text("Apple Pay is not available on this device")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Payment button
    private var paymentButton: some View {
        Button {
            processPayment()
        } label: {
            HStack {
                if isApplePayProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.trailing, 8)
                }
                
                Text("Pay Now")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isApplePayProcessing)
    }
    
    // MARK: - Actions
    
    /// Process the payment based on the selected method
    private func processPayment() {
        switch selectedOption {
        case .card:
            showCardPayment = true
            
        case .applePay:
            processApplePay()
            
        case .bankTransfer:
            showBankTransfer = true
        }
    }
    
    /// Process a payment with Apple Pay
    private func processApplePay() {
        guard let rootVC = UIApplication.shared.windows.first?.rootViewController else { return }
        
        let applePayHandler = ApplePayHandler(
            amount: amount,
            sourceId: sourceId,
            destinationId: destinationId,
            orderId: orderId
        )
        
        isApplePayProcessing = true
        
        applePayHandler.presentApplePay(in: rootVC) { success in
            isApplePayProcessing = false
            
            if success {
                // Create a successful payment result
                let result = PaymentResult(
                    transactionId: UUID().uuidString, // In reality, this would come from the backend
                    status: .completed,
                    errorMessage: nil,
                    metadata: nil
                )
                handlePaymentComplete(result)
            }
        }
    }
    
    /// Handle payment completion
    /// - Parameter result: The payment result
    private func handlePaymentComplete(_ result: PaymentResult) {
        onPaymentComplete(result)
        dismiss()
    }
    
    // MARK: - Helper Properties
    
    /// Check if Apple Pay is available
    private var isApplePayAvailable: Bool {
        ApplePayHandler.applePayStatus().canMakePayments
    }
    
    /// Get the currency symbol for the selected currency
    private var currencySymbol: String {
        switch currency {
        case .usd:
            return "$"
        case .eur:
            return "€"
        case .gbp:
            return "£"
        case .xcd:
            return "EC$"
        }
    }
}

#if DEBUG
/// Preview for the payment sheet
struct PaymentSheet_Previews: PreviewProvider {
    static var previews: some View {
        PaymentSheet(
            amount: 99.99,
            currency: .xcd,
            sourceId: "customer_id",
            destinationId: "merchant_id",
            orderId: "order123"
        ) { result in
            print("Payment completed with status: \(result.status)")
        }
    }
}
#endif 