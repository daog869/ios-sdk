import SwiftUI

struct CardPaymentView: View {
    @StateObject private var viewModel = CardPaymentViewModel()
    @Environment(\.dismiss) var dismiss
    
    var onPaymentComplete: (PaymentResult) -> Void
    
    // Transaction details
    var amount: Decimal
    var currency: Currency
    var sourceId: String
    var destinationId: String
    var orderId: String
    
    init(
        amount: Decimal,
        currency: Currency = .xcd,
        sourceId: String,
        destinationId: String,
        orderId: String,
        onPaymentComplete: @escaping (PaymentResult) -> Void
    ) {
        self.amount = amount
        self.currency = currency
        self.sourceId = sourceId
        self.destinationId = destinationId
        self.orderId = orderId
        self.onPaymentComplete = onPaymentComplete
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        Text(currencySymbol)
                            .font(.headline)
                        Text("\(amount, format: .number.precision(.fractionLength(2)))")
                            .font(.title)
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
                
                Section("Card Information") {
                    TextField("Cardholder Name", text: $viewModel.cardholderName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                    
                    TextField("Card Number", text: $viewModel.cardNumber)
                        .keyboardType(.numberPad)
                        .textContentType(.creditCardNumber)
                    
                    HStack {
                        TextField("MM/YY", text: $viewModel.expiryDate)
                            .keyboardType(.numberPad)
                            .frame(maxWidth: .infinity)
                        
                        Divider()
                        
                        SecureField("CVV", text: $viewModel.cvv)
                            .keyboardType(.numberPad)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                Section("Billing Address") {
                    TextField("Address Line 1", text: $viewModel.addressLine1)
                        .textContentType(.streetAddressLine1)
                    
                    TextField("Address Line 2", text: $viewModel.addressLine2)
                        .textContentType(.streetAddressLine2)
                    
                    TextField("City", text: $viewModel.city)
                        .textContentType(.addressCity)
                    
                    TextField("Postal Code", text: $viewModel.postalCode)
                        .textContentType(.postalCode)
                        .keyboardType(.numberPad)
                    
                    TextField("Country", text: $viewModel.country)
                        .textContentType(.countryName)
                }
                
                Section {
                    Button(action: processPayment) {
                        if viewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Pay \(currencySymbol)\(amount, format: .number.precision(.fractionLength(2)))")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isProcessing || !viewModel.isFormValid)
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Secure Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Payment Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .disabled(viewModel.isProcessing)
        }
    }
    
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
    
    private func processPayment() {
        Task {
            do {
                let result = try await viewModel.processPayment(
                    amount: amount,
                    currency: currency,
                    sourceId: sourceId,
                    destinationId: destinationId,
                    metadata: ["order_id": orderId]
                )
                
                await MainActor.run {
                    onPaymentComplete(result)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError = true
                }
            }
        }
    }
}

@MainActor
class CardPaymentViewModel: ObservableObject {
    @Published var cardholderName = ""
    @Published var cardNumber = ""
    @Published var expiryDate = ""
    @Published var cvv = ""
    @Published var addressLine1 = ""
    @Published var addressLine2 = ""
    @Published var city = ""
    @Published var postalCode = ""
    @Published var country = ""
    
    @Published var isProcessing = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let paymentManager = PaymentManager.shared
    
    var isFormValid: Bool {
        let cardNumberValid = cardNumber.count >= 15 && cardNumber.count <= 19
        let expiryValid = expiryDate.count == 5 && expiryDate.contains("/")
        let cvvValid = cvv.count >= 3 && cvv.count <= 4
        let nameValid = !cardholderName.isEmpty
        
        return cardNumberValid && expiryValid && cvvValid && nameValid
    }
    
    func processPayment(
        amount: Decimal,
        currency: Currency,
        sourceId: String,
        destinationId: String,
        metadata: [String: String]? = nil
    ) async throws -> PaymentResult {
        isProcessing = true
        defer { isProcessing = false }
        
        // Format card details for processing
        guard let cardDetails = formatCardDetails() else {
            throw PaymentError.invalidPaymentMethod
        }
        
        // Add card details to metadata
        var combinedMetadata = metadata ?? [:]
        combinedMetadata["card_last4"] = String(cardNumber.suffix(4))
        combinedMetadata["billing_postal"] = postalCode
        
        // Process the payment
        return try await paymentManager.processPayment(
            amount: amount,
            currency: currency,
            method: .card,
            sourceId: sourceId,
            destinationId: destinationId,
            metadata: combinedMetadata
        )
    }
    
    private func formatCardDetails() -> [String: String]? {
        // Format expiry date
        let components = expiryDate.split(separator: "/")
        guard components.count == 2,
              let month = Int(components[0]),
              let year = Int(components[1]),
              month >= 1, month <= 12 else {
            return nil
        }
        
        // For a real implementation, you'd encrypt this data before transmission
        return [
            "card_number": cardNumber.replacingOccurrences(of: " ", with: ""),
            "expiry_month": String(month),
            "expiry_year": "20\(year)",
            "cvv": cvv,
            "name": cardholderName,
            "address_line1": addressLine1,
            "address_line2": addressLine2,
            "city": city,
            "postal_code": postalCode,
            "country": country
        ]
    }
}

#Preview {
    CardPaymentView(
        amount: 125.50,
        currency: .xcd,
        sourceId: "user123",
        destinationId: "merchant456",
        orderId: "order789"
    ) { result in
        print("Payment completed with status: \(result.status)")
    }
} 