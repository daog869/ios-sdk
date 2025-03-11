import SwiftUI

/// A SwiftUI view for processing card payments
@available(iOS 17.0, macOS 14.0, *)
public struct CardPaymentView: View {
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    @State private var cardNumber = ""
    @State private var expiryDate = ""
    @State private var cvv = ""
    @State private var isProcessing = false
    @State private var error: String?
    
    private let amount: Decimal
    private let currency: String
    private let sourceId: String
    private let destinationId: String
    private let orderId: String
    private let paymentManager: PaymentManager
    private let completion: (PaymentResult) -> Void
    
    // MARK: - Initialization
    
    /// Initialize a card payment view
    /// - Parameters:
    ///   - amount: The payment amount
    ///   - currency: The currency code (e.g. XCD)
    ///   - sourceId: The customer's ID
    ///   - destinationId: The merchant's ID
    ///   - orderId: The unique order identifier
    ///   - completion: Completion handler with payment result
    public init(
        amount: Decimal,
        currency: String,
        sourceId: String,
        destinationId: String,
        orderId: String,
        completion: @escaping (PaymentResult) -> Void
    ) {
        self.amount = amount
        self.currency = currency
        self.sourceId = sourceId
        self.destinationId = destinationId
        self.orderId = orderId
        self.paymentManager = PaymentManager()
        self.completion = completion
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Card Number", text: $cardNumber)
                        .keyboardType(.numberPad)
                        .textContentType(.creditCardNumber)
                    
                    TextField("MM/YY", text: $expiryDate)
                        .keyboardType(.numberPad)
                    
                    SecureField("CVV", text: $cvv)
                        .keyboardType(.numberPad)
                        .textContentType(.creditCardNumber)
                }
                
                Section {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text("\(amount, specifier: "%.2f") \(currency)")
                            .fontWeight(.semibold)
                    }
                }
                
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: processPayment) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Pay \(amount, specifier: "%.2f") \(currency)")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isProcessing || !isValidForm)
                }
            }
            .navigationTitle("Card Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private var isValidForm: Bool {
        // Basic validation
        cardNumber.count >= 15 &&
        expiryDate.count == 5 &&
        cvv.count >= 3
    }
    
    private func processPayment() {
        isProcessing = true
        error = nil
        
        paymentManager.processCardPayment(
            amount: amount,
            currency: currency,
            sourceId: sourceId,
            destinationId: destinationId,
            orderId: orderId
        ) { result in
            isProcessing = false
            
            switch result {
            case .success(let transaction):
                completion(.init(
                    status: .completed,
                    transactionId: transaction.id,
                    errorMessage: nil
                ))
                dismiss()
                
            case .failure(let error):
                self.error = error.localizedDescription
                completion(.init(
                    status: .failed,
                    transactionId: nil,
                    errorMessage: error.localizedDescription
                ))
            }
        }
    }
}

// MARK: - Supporting Types

@available(iOS 17.0, macOS 14.0, *)
public struct PaymentResult {
    public let status: PaymentStatus
    public let transactionId: String?
    public let errorMessage: String?
    
    public enum PaymentStatus {
        case completed
        case failed
        case cancelled
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    CardPaymentView(
        amount: 99.99,
        currency: "XCD",
        sourceId: "customer123",
        destinationId: "merchant456",
        orderId: "order789"
    ) { result in
        print("Payment result: \(result)")
    }
} 