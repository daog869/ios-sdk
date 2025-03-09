import SwiftUI
import SwiftData
import Vizion_Gateway
import Charts

// Using types directly from the main module
// No need for struct imports or _exported imports

struct PaymentView: View {
    let paymentMethod: PaymentMethod
    let prefillData: PaymentData?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String = ""
    @State private var transactionDescription: String = ""
    @State private var isProcessing = false
    @State private var showingConfirmation = false
    @State private var merchantName = ""
    @State private var reference: String?
    
    init(paymentMethod: PaymentMethod, prefillData: PaymentData? = nil) {
        self.paymentMethod = paymentMethod
        self.prefillData = prefillData
        
        if let data = prefillData {
            _amount = State(initialValue: String(describing: data.amount))
            _merchantName = State(initialValue: data.merchantName)
            _reference = State(initialValue: data.reference)
        }
    }
    
    var formattedAmount: Decimal? {
        return Decimal(string: amount)
    }
    
    var isFormValid: Bool {
        guard let amount = formattedAmount else { return false }
        return amount > 0 && !merchantName.isEmpty
    }
    
    var body: some View {
        Form {
            Section("Payment Details") {
                TextField("Amount (XCD)", text: $amount)
                    .keyboardType(.decimalPad)
                    .disabled(prefillData != nil)
                
                TextField("Merchant Name", text: $merchantName)
                    .disabled(prefillData != nil)
                
                TextField("Description (Optional)", text: $transactionDescription)
                
                if let reference = reference {
                    LabeledContent("Reference", value: reference)
                }
            }
            
            Section("Payment Method") {
                HStack {
                    Label(
                        paymentMethod.rawValue,
                        systemImage: iconForPaymentMethod(paymentMethod)
                    )
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            
            Section {
                Button(action: processPayment) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Process Payment")
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(!isFormValid || isProcessing)
            }
        }
        .navigationTitle("Payment Details")
        .alert("Payment Confirmation", isPresented: $showingConfirmation) {
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("Payment processed successfully!")
        }
    }
    
    private func iconForPaymentMethod(_ method: PaymentMethod) -> String {
        switch method {
        case .debitCard: return "creditcard.fill"
        case .creditCard: return "creditcard.circle.fill"
        case .bankTransfer: return "building.columns.fill"
        case .mobileMoney: return "iphone.gen3"
        case .qrCode: return "qrcode"
        case .wallet: return "wallet.pass.fill"
        }
    }
    
    private func processPayment() {
        guard let amount = formattedAmount else { return }
        
        isProcessing = true
        
        // Simulate payment processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            let transaction = Transaction(
                amount: amount,
                type: TransactionType.payment,
                paymentMethod: paymentMethod,
                transactionDescription: transactionDescription.isEmpty ? nil : transactionDescription,
                merchantId: "MERCH123", // In real app, get from authenticated merchant
                merchantName: merchantName,
                reference: reference ?? UUID().uuidString
            )
            
            modelContext.insert(transaction)
            
            isProcessing = false
            showingConfirmation = true
        })
    }
}

#Preview {
    PaymentView(paymentMethod: .creditCard)
        .modelContainer(for: Transaction.self, inMemory: true)
} 
