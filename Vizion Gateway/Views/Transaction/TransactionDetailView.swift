import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isLoading = false
    @State private var errorMessage: AppError?
    @State private var showingRefundSheet = false
    @State private var showingDisputeSheet = false
    @State private var showingReceiptSheet = false
    @State private var showConfirmation = false
    @State private var actionType: TransactionAction = .refund
    
    enum TransactionAction {
        case refund, dispute, cancel
    }
    
    var body: some View {
        List {
            // Transaction Summary Section
            Section {
                VStack(spacing: 12) {
                    // Transaction status indicator
                    HStack {
                        Spacer()
                        StatusBadge(status: transaction.status)
                        Spacer()
                    }
                    
                    // Transaction amount
                    Text(transaction.amount.formatted(.currency(code: transaction.currency)))
                        .font(.system(size: 36, weight: .bold))
                    
                    // Transaction date
                    Text(formatDate(transaction.timestamp))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Transaction ID
                    HStack {
                        Text("ID: \(transaction.id)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            UIPasteboard.general.string = transaction.id
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            
            // Transaction Details
            Section("Transaction Details") {
                DetailRow(key: "Type", value: transaction.type.rawValue)
                DetailRow(key: "Payment Method", value: transaction.paymentMethod.rawValue)
                DetailRow(key: "Status", value: transaction.status.rawValue)
                
                if let description = transaction.transactionDescription {
                    DetailRow(key: "Description", value: description)
                }
                
                DetailRow(key: "Reference", value: transaction.reference)
                
                if let externalRef = transaction.externalReference {
                    DetailRow(key: "External Reference", value: externalRef)
                }
            }
            
            // Financial Information
            Section("Financial Details") {
                DetailRow(key: "Amount", value: transaction.amount.formatted(.currency(code: transaction.currency)))
                DetailRow(key: "Fee", value: transaction.fee.formatted(.currency(code: transaction.currency)))
                DetailRow(key: "Net Amount", value: transaction.netAmount.formatted(.currency(code: transaction.currency)))
                DetailRow(key: "Currency", value: transaction.currency)
            }
            
            // Customer & Merchant Information
            Section("Parties") {
                DetailRow(key: "Merchant", value: transaction.merchantName)
                DetailRow(key: "Merchant ID", value: transaction.merchantId)
                
                if let customerName = transaction.customerName {
                    DetailRow(key: "Customer", value: customerName)
                }
                
                if let customerId = transaction.customerId {
                    DetailRow(key: "Customer ID", value: customerId)
                }
            }
            
            // Processing Information
            if let processorResponse = transaction.processorResponse {
                Section("Processing Details") {
                    DetailRow(key: "Processor Response", value: processorResponse)
                    
                    if let errorMessage = transaction.errorMessage {
                        DetailRow(key: "Error Message", value: errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Actions
            Section {
                if transaction.status == .completed {
                    Button("Refund Transaction") {
                        actionType = .refund
                        showingRefundSheet = true
                    }
                    .foregroundColor(.blue)
                }
                
                if transaction.status != .disputed && transaction.status != .refunded {
                    Button("Report Dispute") {
                        actionType = .dispute
                        showingDisputeSheet = true
                    }
                    .foregroundColor(.orange)
                }
                
                if transaction.status == .pending {
                    Button("Cancel Transaction") {
                        actionType = .cancel
                        showConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                
                Button("View Receipt") {
                    showingReceiptSheet = true
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: shareTransaction) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: exportPDF) {
                        Label("Export PDF", systemImage: "doc.richtext")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .withErrorHandling($errorMessage)
        .sheet(isPresented: $showingRefundSheet) {
            RefundFormView(transaction: transaction)
        }
        .sheet(isPresented: $showingDisputeSheet) {
            DisputeFormView(transaction: transaction)
        }
        .sheet(isPresented: $showingReceiptSheet) {
            ReceiptView(transaction: transaction)
        }
        .confirmationDialog(
            actionTypeTitle,
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button(actionTypeButtonTitle, role: .destructive) {
                performAction()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(actionTypeMessage)
        }
    }
    
    // MARK: - Helper Properties
    
    private var actionTypeTitle: String {
        switch actionType {
        case .refund: return "Refund Transaction"
        case .dispute: return "Report Dispute"
        case .cancel: return "Cancel Transaction"
        }
    }
    
    private var actionTypeButtonTitle: String {
        switch actionType {
        case .refund: return "Refund"
        case .dispute: return "Report"
        case .cancel: return "Cancel Transaction"
        }
    }
    
    private var actionTypeMessage: String {
        switch actionType {
        case .refund:
            return "Are you sure you want to refund this transaction? This action cannot be undone."
        case .dispute:
            return "Are you sure you want to report a dispute for this transaction?"
        case .cancel:
            return "Are you sure you want to cancel this transaction? This action cannot be undone."
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func shareTransaction() {
        // Create transaction summary text
        let transactionText = """
        Transaction ID: \(transaction.id)
        Amount: \(transaction.amount.formatted(.currency(code: transaction.currency)))
        Date: \(formatDate(transaction.timestamp))
        Status: \(transaction.status.rawValue)
        Merchant: \(transaction.merchantName)
        """
        
        // Share transaction information
        let activityVC = UIActivityViewController(
            activityItems: [transactionText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func exportPDF() {
        // In a real app, this would generate a PDF with transaction details
    }
    
    private func performAction() {
        isLoading = true
        
        Task {
            do {
                switch actionType {
                case .refund:
                    try await refundTransaction()
                case .dispute:
                    try await reportDispute()
                case .cancel:
                    try await cancelTransaction()
                }
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = AppError.from(error)
                    isLoading = false
                }
            }
        }
    }
    
    private func refundTransaction() async throws {
        // In a real app, this would call an API to process the refund
        // Update the transaction status
        let updatedTransaction = transaction
        updatedTransaction.status = .refunded
        
        try await FirebaseManager.shared.updateTransaction(updatedTransaction)
    }
    
    private func reportDispute() async throws {
        // In a real app, this would call an API to report a dispute
        // Update the transaction status
        let updatedTransaction = transaction
        updatedTransaction.status = .disputed
        
        try await FirebaseManager.shared.updateTransaction(updatedTransaction)
    }
    
    private func cancelTransaction() async throws {
        // In a real app, this would call an API to cancel the transaction
        // Update the transaction status
        let updatedTransaction = transaction
        updatedTransaction.status = .cancelled
        
        try await FirebaseManager.shared.updateTransaction(updatedTransaction)
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let key: String
    let value: String
    
    var body: some View {
        HStack {
            Text(key)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct RefundFormView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @State private var refundAmount: String
    @State private var refundReason = "Customer Request"
    @State private var isFullRefund = true
    @State private var isLoading = false
    @State private var errorMessage: AppError?
    
    init(transaction: Transaction) {
        self.transaction = transaction
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        self._refundAmount = State(initialValue: formatter.string(from: NSDecimalNumber(decimal: transaction.amount)) ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Full Refund", isOn: $isFullRefund)
                    
                    if !isFullRefund {
                        HStack {
                            Text("Refund Amount")
                            Spacer()
                            TextField("Amount", text: $refundAmount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    Picker("Reason", selection: $refundReason) {
                        Text("Customer Request").tag("Customer Request")
                        Text("Product Issue").tag("Product Issue")
                        Text("Service Issue").tag("Service Issue")
                        Text("Order Cancelled").tag("Order Cancelled")
                        Text("Other").tag("Other")
                    }
                }
                
                Section {
                    Button("Process Refund") {
                        processRefund()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(isLoading || (!isFullRefund && !isValidAmount))
                }
            }
            .navigationTitle("Refund Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .withErrorHandling($errorMessage)
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }
    
    private var isValidAmount: Bool {
        guard let amount = Decimal(string: refundAmount) else { return false }
        return amount > 0 && amount <= transaction.amount
    }
    
    private func processRefund() {
        isLoading = true
        
        // In a real app, this would call an API to process the refund
        
        // Simulate a delay for the refund processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            dismiss()
        }
    }
}

struct DisputeFormView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @State private var disputeReason = "Unauthorized Transaction"
    @State private var disputeDescription = ""
    @State private var isLoading = false
    @State private var errorMessage: AppError?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Reason", selection: $disputeReason) {
                        Text("Unauthorized Transaction").tag("Unauthorized Transaction")
                        Text("Product Not Received").tag("Product Not Received")
                        Text("Product Not as Described").tag("Product Not as Described")
                        Text("Duplicate Charge").tag("Duplicate Charge")
                        Text("Incorrect Amount").tag("Incorrect Amount")
                        Text("Other").tag("Other")
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Description")
                        TextEditor(text: $disputeDescription)
                            .frame(minHeight: 100)
                            .padding(4)
                    }
                }
                
                Section {
                    Button("Submit Dispute") {
                        submitDispute()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(isLoading || disputeDescription.isEmpty)
                }
            }
            .navigationTitle("Report Dispute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .withErrorHandling($errorMessage)
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }
    
    private func submitDispute() {
        isLoading = true
        
        // In a real app, this would call an API to submit the dispute
        
        // Simulate a delay for the dispute submission
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            dismiss()
        }
    }
}

struct ReceiptView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Receipt header
                    VStack(spacing: 8) {
                        Text("RECEIPT")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Transaction ID: \(transaction.id)")
                            .font(.caption)
                    }
                    .padding(.top, 20)
                    
                    // Merchant info
                    VStack(spacing: 4) {
                        Text(transaction.merchantName)
                            .font(.headline)
                        
                        Text("Merchant ID: \(transaction.merchantId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Transaction details
                    VStack(spacing: 12) {
                        HStack {
                            Text("Date:")
                            Spacer()
                            Text(formatDate(transaction.timestamp))
                        }
                        
                        HStack {
                            Text("Status:")
                            Spacer()
                            StatusBadge(status: transaction.status)
                        }
                        
                        HStack {
                            Text("Payment Method:")
                            Spacer()
                            Text(transaction.paymentMethod.rawValue)
                        }
                        
                        if let description = transaction.transactionDescription {
                            HStack {
                                Text("Description:")
                                Spacer()
                                Text(description)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Amount details
                    VStack(spacing: 12) {
                        HStack {
                            Text("Subtotal:")
                            Spacer()
                            Text(transaction.amount.formatted(.currency(code: transaction.currency)))
                        }
                        
                        HStack {
                            Text("Fee:")
                            Spacer()
                            Text(transaction.fee.formatted(.currency(code: transaction.currency)))
                        }
                        
                        HStack {
                            Text("Total:")
                                .font(.headline)
                            Spacer()
                            Text(transaction.netAmount.formatted(.currency(code: transaction.currency)))
                                .font(.headline)
                        }
                    }
                    
                    Divider()
                    
                    // QR code
                    Image(systemName: "qrcode")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .padding()
                    
                    Text("Thank you for your business")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                }
                .padding()
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareReceipt) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func shareReceipt() {
        // In a real app, this would generate a PDF receipt and share it
    }
}

struct TransactionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            // Create a sample transaction for preview
            TransactionDetailView(transaction: Transaction(
                id: "TX123456789",
                amount: 125.99,
                currency: "XCD",
                status: .completed,
                type: .payment,
                paymentMethod: .creditCard,
                timestamp: Date(),
                merchantId: "M12345",
                merchantName: "Sample Merchant",
                reference: "REF123456",
                fee: 3.99,
                netAmount: 122.00
            ))
        }
    }
} 