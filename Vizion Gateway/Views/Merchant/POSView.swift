import SwiftUI
import SwiftData
import CoreNFC

struct POSView: View {
    @StateObject private var viewModel = POSViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var showingPaymentComplete = false
    @State private var showingNFCError = false
    @State private var nfcErrorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Point of Sale")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                NavigationLink(destination: POSCheckoutView()) {
                    HStack {
                        Image(systemName: "cart.fill")
                        Text("Multi-Item Checkout")
                    }
                    .padding(8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            // Amount Input
            AmountInputView(amount: $viewModel.amount)
                .padding()
            
            // Payment Method Selection
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
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Item Description
            TextField("Description (optional)", text: $viewModel.description)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            
            // Card Reader Section
            if viewModel.selectedPaymentMethod == .debitCard || viewModel.selectedPaymentMethod == .creditCard {
                CardReaderView(
                    isScanning: $viewModel.isNFCScanning,
                    onStartScan: {
                        viewModel.startNFCSession()
                    },
                    onCardDetected: {
                        viewModel.processCardPayment(modelContext: modelContext)
                        showingPaymentComplete = true
                    }
                )
                .frame(height: 180)
                .padding()
            }
            
            // QR Code Section
            else if viewModel.selectedPaymentMethod == .qrCode {
                QRPaymentView(amount: viewModel.amount, onPaymentComplete: {
                    viewModel.processQRPayment(modelContext: modelContext)
                    showingPaymentComplete = true
                })
                .frame(height: 180)
                .padding()
            }
            
            // Mobile Payment Section
            else if viewModel.selectedPaymentMethod == .mobileMoney {
                MobilePaymentView(amount: viewModel.amount, onPaymentComplete: {
                    viewModel.processMobilePayment(modelContext: modelContext)
                    showingPaymentComplete = true
                })
                .frame(height: 180)
                .padding()
            }
            
            // Bank Transfer Section
            else if viewModel.selectedPaymentMethod == .bankTransfer {
                BankTransferView(amount: viewModel.amount, onPaymentComplete: {
                    viewModel.processBankTransfer(modelContext: modelContext)
                    showingPaymentComplete = true
                })
                .frame(height: 180)
                .padding()
            }
            
            Spacer()
            
            // Process Payment Button
            Button(action: {
                switch viewModel.selectedPaymentMethod {
                case .debitCard, .creditCard:
                    viewModel.startNFCSession()
                case .qrCode:
                    viewModel.showQRCode = true
                case .mobileMoney:
                    viewModel.processMobilePayment(modelContext: modelContext)
                    showingPaymentComplete = true
                case .bankTransfer:
                    viewModel.processBankTransfer(modelContext: modelContext)
                    showingPaymentComplete = true
                case .wallet:
                    viewModel.processWalletPayment(modelContext: modelContext)
                    showingPaymentComplete = true
                }
            }) {
                Text("Process Payment")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .disabled(viewModel.amount <= 0)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .alert("Payment Complete", isPresented: $showingPaymentComplete) {
            Button("OK", role: .cancel) {
                viewModel.resetForm()
            }
        } message: {
            Text("Transaction ID: \(viewModel.lastTransactionId)\nAmount: $\(String(format: "%.2f", NSDecimalNumber(decimal: viewModel.amount).doubleValue))")
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
}

struct AmountInputView: View {
    @Binding var amount: Decimal
    @State private var amountString = ""
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Amount")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(alignment: .center) {
                Text("$")
                    .font(.system(size: 36, weight: .bold))
                
                TextField("0.00", text: $amountString)
                    .font(.system(size: 36, weight: .bold))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .onChange(of: amountString) {
                        if let value = Decimal(string: amountString) {
                            amount = value
                        } else if amountString.isEmpty {
                            amount = 0
                        }
                    }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

struct PaymentMethodButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.secondary.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .blue : .primary)
            }
        }
    }
}

struct CardReaderView: View {
    @Binding var isScanning: Bool
    let onStartScan: () -> Void
    let onCardDetected: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if isScanning {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .trim(from: 0, to: 0.75)
                            .stroke(Color.blue, lineWidth: 4)
                            .frame(width: 100, height: 100)
                            .rotationEffect(Angle(degrees: isScanning ? 360 : 0))
                            .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isScanning)
                        
                        Image(systemName: "creditcard.and.contactless")
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                    }
                    
                    Text("Ready to Scan")
                        .font(.headline)
                    
                    Text("Hold card near device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: onStartScan) {
                    HStack {
                        Image(systemName: "creditcard.and.contactless")
                        Text("Tap to Scan Card")
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

struct QRPaymentView: View {
    let amount: Decimal
    let onPaymentComplete: () -> Void
    @State private var isGenerating = false
    
    var body: some View {
        VStack(spacing: 12) {
            if isGenerating {
                Image("sample-qr-code") // Use actual QR code generation in real app
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 150, height: 150)
                
                Text("Scan to Pay")
                    .font(.headline)
                
                Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue))")
                    .font(.subheadline)
            } else {
                Button(action: {
                    isGenerating = true
                    // Simulate payment completion after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        onPaymentComplete()
                    }
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

struct MobilePaymentView: View {
    let amount: Decimal
    let onPaymentComplete: () -> Void
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

struct BankTransferView: View {
    let amount: Decimal
    let onPaymentComplete: () -> Void
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

@MainActor
class POSViewModel: ObservableObject {
    @Published var amount: Decimal = 0
    @Published var selectedPaymentMethod: PaymentMethod = .debitCard
    @Published var description: String = ""
    @Published var isNFCScanning = false
    @Published var showQRCode = false
    @Published var nfcError: String?
    @Published var lastTransactionId = ""
    
    private var nfcSession: NFCTagReaderSession?
    
    func startNFCSession() {
        guard NFCTagReaderSession.readingAvailable else {
            nfcError = "NFC is not available on this device"
            return
        }
        
        isNFCScanning = true
        
        // In a real app, this would actually initiate an NFC session
        // For this demo, we'll simulate card detection after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isNFCScanning = false
            // Safely create the model context
            do {
                let container = try ModelContainer(for: Transaction.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
                let context = ModelContext(container)
                self.processCardPayment(modelContext: context)
            } catch {
                print("Error creating model container: \(error.localizedDescription)")
                self.nfcError = "Failed to process payment: \(error.localizedDescription)"
            }
        }
    }
    
    func processCardPayment(modelContext: ModelContext) {
        guard amount > 0 else { return }
        
        let transaction = createTransaction(
            paymentMethod: selectedPaymentMethod,
            status: .completed
        )
        
        modelContext.insert(transaction)
        lastTransactionId = transaction.id
    }
    
    func processQRPayment(modelContext: ModelContext) {
        let transaction = createTransaction(
            paymentMethod: .qrCode,
            status: .completed
        )
        
        modelContext.insert(transaction)
        lastTransactionId = transaction.id
    }
    
    func processMobilePayment(modelContext: ModelContext) {
        let transaction = createTransaction(
            paymentMethod: .mobileMoney,
            status: .completed
        )
        
        modelContext.insert(transaction)
        lastTransactionId = transaction.id
    }
    
    func processBankTransfer(modelContext: ModelContext) {
        let transaction = createTransaction(
            paymentMethod: .bankTransfer,
            status: .pending
        )
        
        modelContext.insert(transaction)
        lastTransactionId = transaction.id
    }
    
    func processWalletPayment(modelContext: ModelContext) {
        let transaction = createTransaction(
            paymentMethod: .wallet,
            status: .completed
        )
        
        modelContext.insert(transaction)
        lastTransactionId = transaction.id
    }
    
    private func createTransaction(paymentMethod: PaymentMethod, status: TransactionStatus) -> Transaction {
        return Transaction(
            amount: amount,
            status: status,
            type: .payment,
            paymentMethod: paymentMethod,
            transactionDescription: description.isEmpty ? nil : description,
            merchantId: "MERCH123", // In a real app, get from authenticated merchant
            merchantName: "Vizion POS",
            reference: "POS-\(UUID().uuidString.prefix(8))"
        )
    }
    
    func resetForm() {
        amount = 0
        description = ""
    }
}

// Note: This is a stub definition since the actual implementation would require real NFC hardware
// In a real app, you would implement the NFCTagReaderSessionDelegate protocol
class NFCTagReaderSession {
    static var readingAvailable: Bool {
        // In a real app, this would check hardware availability
        // For the demo, we'll return true if running on a device that might support NFC
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }
}

#Preview {
    POSView()
        .modelContainer(for: Transaction.self, inMemory: true)
} 