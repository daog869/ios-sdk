import SwiftUI

struct TestTransactionComponent: View {
    @StateObject private var apiService = APIService.shared
    @State private var amount = ""
    @State private var currency = "XCD"
    @State private var paymentMethod = "card"
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section("Transaction Details") {
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                
                Picker("Payment Method", selection: $paymentMethod) {
                    Text("Card").tag("card")
                    Text("Bank Transfer").tag("bank")
                    Text("Mobile Money").tag("mobile")
                }
                
                Button {
                    createTestTransaction()
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Create Test Transaction")
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(amount.isEmpty || isLoading)
            }
            
            Section("Test Cards") {
                VStack(alignment: .leading) {
                    Text("Success")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("4242 4242 4242 4242")
                        .font(.system(.body, design: .monospaced))
                }
                
                VStack(alignment: .leading) {
                    Text("Insufficient Funds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("4000 0000 0000 9995")
                        .font(.system(.body, design: .monospaced))
                }
                
                VStack(alignment: .leading) {
                    Text("Requires Authentication")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("4000 0025 0000 3155")
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .navigationTitle("Test Transaction")
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Test transaction created successfully")
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private func createTestTransaction() {
        guard let amountDecimal = Decimal(string: amount) else {
            errorMessage = "Invalid amount"
            return
        }
        
        isLoading = true
        Task {
            do {
                let transaction = try await apiService.createTestTransaction(
                    amount: amountDecimal,
                    currency: currency,
                    paymentMethod: paymentMethod
                )
                await MainActor.run {
                    isLoading = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
} 