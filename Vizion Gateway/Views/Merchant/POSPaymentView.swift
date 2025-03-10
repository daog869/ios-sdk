import SwiftUI
import SwiftData
import CoreNFC

struct POSPaymentView: View {
    let amount: Decimal
    let items: [CartItem]
    let discount: Decimal
    let tax: Decimal
    let onPaymentComplete: (Transaction) -> Void
    
    @StateObject private var viewModel = POSPaymentViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var showingNFCError = false
    @State private var nfcErrorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Amount Display
            VStack(spacing: 8) {
                Text("Total Amount")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(alignment: .center) {
                    Text("$")
                        .font(.system(size: 36, weight: .bold))
                    
                    Text(formatCurrency(amount))
                        .font(.system(size: 36, weight: .bold))
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            // Payment Method Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Payment Method")
                    .font(.headline)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        PaymentMethodButton(
                            title: "Card",
                            icon: "creditcard.fill",
                            isSelected: viewModel.selectedPaymentMethod == .debitCard || viewModel.selectedPaymentMethod == .creditCard,
                            action: { viewModel.selectedPaymentMethod = .debitCard }
                        )
                        
                        PaymentMethodButton(
                            title: "QR",
                            icon: "qrcode",
                            isSelected: viewModel.selectedPaymentMethod == .qrCode,
                            action: { viewModel.selectedPaymentMethod = .qrCode }
                        )
                        
                        PaymentMethodButton(
                            title: "Mobile",
                            icon: "iphone",
                            isSelected: viewModel.selectedPaymentMethod == .mobileMoney,
                            action: { viewModel.selectedPaymentMethod = .mobileMoney }
                        )
                        
                        PaymentMethodButton(
                            title: "Bank",
                            icon: "building.columns.fill",
                            isSelected: viewModel.selectedPaymentMethod == .bankTransfer,
                            action: { viewModel.selectedPaymentMethod = .bankTransfer }
                        )
                        
                        PaymentMethodButton(
                            title: "Wallet",
                            icon: "wallet.pass.fill",
                            isSelected: viewModel.selectedPaymentMethod == .wallet,
                            action: { viewModel.selectedPaymentMethod = .wallet }
                        )
                    }
                    .padding(.horizontal)
                }
            }
            
            // Customer Information (optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("Customer Information (Optional)")
                    .font(.headline)
                    .padding(.horizontal)
                
                TextField("Customer Name", text: $viewModel.customerName)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                TextField("Customer Email", text: $viewModel.customerEmail)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            // Card Reader Section
            if viewModel.selectedPaymentMethod == .debitCard || viewModel.selectedPaymentMethod == .creditCard {
                CardReaderSection(isScanning: $viewModel.isNFCScanning) {
                    processPayment()
                }
            }
            
            // QR Code Section
            else if viewModel.selectedPaymentMethod == .qrCode {
                QRCodeSection(amount: amount) {
                    processPayment()
                }
            }
            
            // Mobile Payment Section
            else if viewModel.selectedPaymentMethod == .mobileMoney {
                MobilePaymentSection(amount: amount) {
                    processPayment()
                }
            }
            
            // Bank Transfer Section
            else if viewModel.selectedPaymentMethod == .bankTransfer {
                BankTransferSection(amount: amount) {
                    processPayment()
                }
            }
            
            // Digital Wallet Section
            else if viewModel.selectedPaymentMethod == .wallet {
                WalletPaymentSection(amount: amount) {
                    processPayment()
                }
            }
            
            Spacer()
            
            // Process Payment Button
            Button(action: {
                processPayment()
            }) {
                Text("Process Payment")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .alert("NFC Error", isPresented: $showingNFCError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(nfcErrorMessage)
        }
        .onReceive(viewModel.$nfcError) { error in
            if let error = error {
                nfcErrorMessage = error
                showingNFCError = true
            }
        }
    }
    
    private func processPayment() {
        let metadata = createMetadata()
        let transaction = viewModel.processPayment(
            modelContext: modelContext,
            amount: amount,
            metadata: metadata
        )
        onPaymentComplete(transaction)
    }
    
    private func createMetadata() -> String? {
        // Create a metadata JSON string with cart items, discount, and tax information
        let itemsData = items.map { [
            "name": $0.name,
            "price": "\($0.price)",
            "quantity": "\($0.quantity)",
            "subtotal": "\($0.subtotal)"
        ]}
        
        let metadata: [String: Any] = [
            "items": itemsData,
            "subtotal": "\(items.reduce(Decimal(0)) { $0 + $1.subtotal })",
            "discount": "\(discount)",
            "tax": "\(tax)",
            "customerName": viewModel.customerName,
            "customerEmail": viewModel.customerEmail
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted])
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error creating metadata JSON: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "XCD"
        formatter.currencySymbol = ""  // We're already showing $ separately
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

// MARK: - Payment Method Components

struct CardReaderSection: View {
    @Binding var isScanning: Bool
    var onCardDetected: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Tap to Scan Card")
                .font(.headline)
            
            if isScanning {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                
                Text("Hold card near the device...")
                    .foregroundColor(.secondary)
            } else {
                Button(action: {
                    // Simulate NFC scanning
                    isScanning = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isScanning = false
                        onCardDetected()
                    }
                }) {
                    Image(systemName: "creditcard.and.123")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(15)
    }
}

struct QRCodeSection: View {
    let amount: Decimal
    var onPaymentComplete: () -> Void
    @State private var showQRCode = false
    
    var body: some View {
        VStack(spacing: 12) {
            if showQRCode {
                Image(systemName: "qrcode")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                
                Text("Scan this QR code to pay")
                    .foregroundColor(.secondary)
                
                // Simulate payment completion after delay
                Text("Waiting for payment...")
                    .foregroundColor(.secondary)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            onPaymentComplete()
                        }
                    }
            } else {
                Button(action: {
                    showQRCode = true
                }) {
                    HStack {
                        Image(systemName: "qrcode")
                        Text("Generate QR Code")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(15)
    }
}

struct MobilePaymentSection: View {
    let amount: Decimal
    var onPaymentComplete: () -> Void
    @State private var phoneNumber = ""
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Customer Phone Number", text: $phoneNumber)
                .keyboardType(.phonePad)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
            
            Button(action: {
                // Validate phone number
                guard !phoneNumber.isEmpty else { return }
                onPaymentComplete()
            }) {
                HStack {
                    Image(systemName: "iphone")
                    Text("Send Payment Request")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .disabled(phoneNumber.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(15)
    }
}

struct BankTransferSection: View {
    let amount: Decimal
    var onPaymentComplete: () -> Void
    @State private var accountNumber = ""
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Account Number", text: $accountNumber)
                .keyboardType(.numberPad)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
            
            Button(action: {
                // Validate account number
                guard !accountNumber.isEmpty else { return }
                onPaymentComplete()
            }) {
                HStack {
                    Image(systemName: "building.columns")
                    Text("Process Bank Transfer")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .disabled(accountNumber.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(15)
    }
}

struct WalletPaymentSection: View {
    let amount: Decimal
    var onPaymentComplete: () -> Void
    @State private var walletId = ""
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Wallet ID or Username", text: $walletId)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
            
            Button(action: {
                // Validate wallet ID
                guard !walletId.isEmpty else { return }
                onPaymentComplete()
            }) {
                HStack {
                    Image(systemName: "wallet.pass")
                    Text("Pay with Wallet")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .disabled(walletId.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(15)
    }
}

// MARK: - ViewModel

@MainActor
class POSPaymentViewModel: ObservableObject {
    @Published var selectedPaymentMethod: PaymentMethod = .debitCard
    @Published var customerName: String = ""
    @Published var customerEmail: String = ""
    @Published var isNFCScanning = false
    @Published var nfcError: String?
    
    func processPayment(
        modelContext: ModelContext,
        amount: Decimal,
        metadata: String?
    ) -> Transaction {
        let transaction = Transaction(
            amount: amount,
            status: .completed,
            type: .payment,
            paymentMethod: selectedPaymentMethod,
            transactionDescription: "POS Sale",
            metadata: metadata,
            merchantId: "MERCH123", // In a real app, get from authenticated merchant
            merchantName: "Vizion POS",
            customerId: customerEmail.isEmpty ? nil : "CUST-\(UUID().uuidString.prefix(8))",
            customerName: customerName.isEmpty ? nil : customerName,
            reference: "POS-\(UUID().uuidString.prefix(8))"
        )
        
        modelContext.insert(transaction)
        return transaction
    }
}

// Preview provider
#Preview {
    POSPaymentView(
        amount: 125.75,
        items: [
            CartItem(name: "Coffee", price: 5.50, quantity: 2),
            CartItem(name: "Sandwich", price: 8.75, quantity: 1)
        ],
        discount: 2.00,
        tax: 3.00
    ) { _ in }
    .modelContainer(for: Transaction.self, inMemory: true)
} 