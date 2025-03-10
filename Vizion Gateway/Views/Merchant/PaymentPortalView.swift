import SwiftUI
import PassKit

struct PaymentPortalView: View {
    @State private var amount: String = ""
    @State private var description: String = ""
    @State private var showingCardEntry = false
    @State private var isProcessing = false
    @State private var errorMessage: VizionAppError?
    @State private var paymentSuccess = false
    
    // Payment request configuration
    private var paymentRequest: PKPaymentRequest {
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.viziongw.payments"
        request.supportedNetworks = [.visa, .masterCard, .amex]
        request.merchantCapabilities = .capability3DS
        request.countryCode = "KN"
        request.currencyCode = "XCD"
        
        if let amount = Decimal(string: amount) {
            request.paymentSummaryItems = [
                PKPaymentSummaryItem(label: description.isEmpty ? "Payment" : description,
                                   amount: NSDecimalNumber(decimal: amount))
            ]
        }
        
        return request
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Payment Details") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    TextField("Description", text: $description)
                }
                
                Section {
                    // Card Entry Button
                    Button {
                        showingCardEntry = true
                    } label: {
                        HStack {
                            Image(systemName: "creditcard")
                            Text("Enter Card Details")
                        }
                    }
                    .disabled(amount.isEmpty || isProcessing)
                    
                    // Apple Pay Button
                    if PKPaymentAuthorizationController.canMakePayments() {
                        PaymentButton {
                            await processApplePayment()
                        }
                        .disabled(amount.isEmpty || isProcessing)
                    }
                }
                
                if isProcessing {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.5)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Payment Portal")
            .sheet(isPresented: $showingCardEntry) {
                CardEntryView(amount: amount, description: description) { success in
                    if success {
                        paymentSuccess = true
                    }
                }
            }
            .alert("Payment Successful", isPresented: $paymentSuccess) {
                Button("OK") { }
            }
            .withErrorHandling($errorMessage)
        }
    }
    
    private func processApplePayment() async {
        guard let amount = Decimal(string: amount) else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let controller = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
            let success = try await controller.present()
            
            if success {
                paymentSuccess = true
            }
        } catch {
            errorMessage = .paymentProcessingError(error.localizedDescription)
        }
    }
}

struct CardEntryView: View {
    let amount: String
    let description: String
    let onCompletion: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var cardNumber = ""
    @State private var expiryDate = ""
    @State private var cvv = ""
    @State private var isProcessing = false
    @State private var errorMessage: VizionAppError?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Card Details") {
                    TextField("Card Number", text: $cardNumber)
                        .keyboardType(.numberPad)
                        .textContentType(.creditCardNumber)
                    
                    TextField("MM/YY", text: $expiryDate)
                        .keyboardType(.numberPad)
                    
                    SecureField("CVV", text: $cvv)
                        .keyboardType(.numberPad)
                        .textContentType(.creditCardNumber)
                }
                
                Section("Payment Summary") {
                    if let amountDecimal = Decimal(string: amount) {
                        LabeledContent("Amount", value: amountDecimal.formatted(.currency(code: "XCD")))
                    }
                    if !description.isEmpty {
                        LabeledContent("Description", value: description)
                    }
                }
                
                Section {
                    Button {
                        Task {
                            await processCardPayment()
                        }
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Process Payment")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isProcessing || !isValidForm)
                }
            }
            .navigationTitle("Card Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .withErrorHandling($errorMessage)
        }
    }
    
    private var isValidForm: Bool {
        cardNumber.count >= 15 &&
        expiryDate.count == 5 &&
        cvv.count >= 3
    }
    
    private func processCardPayment() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Here you would integrate with your payment processor
            // For now, we'll simulate a successful payment
            try await Task.sleep(nanoseconds: 2_000_000_000)
            onCompletion(true)
            dismiss()
        } catch {
            errorMessage = .paymentProcessingError(error.localizedDescription)
        }
    }
}

struct PaymentButton: View {
    let action: () async -> Void
    
    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack {
                Image(systemName: "applelogo")
                Text("Pay with Apple Pay")
            }
        }
    }
} 