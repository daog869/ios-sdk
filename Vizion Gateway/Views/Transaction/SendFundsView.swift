import SwiftUI
import SwiftData

struct SendFundsView: View {
    @StateObject private var viewModel = SendFundsViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Send Funds")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Quick, secure payments to anyone")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.1))
            
            ScrollView {
                VStack(spacing: 24) {
                    // Recipient Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipient")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Toggle("Select from contacts", isOn: $viewModel.selectFromContacts)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }
                        
                        if viewModel.selectFromContacts {
                            ContactSelectorView(selectedContact: $viewModel.selectedContact)
                                .frame(height: 200)
                        } else {
                            TextField("Recipient Email or Phone", text: $viewModel.recipientIdentifier)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Amount Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .center) {
                            Text("$")
                                .font(.system(size: 36, weight: .bold))
                            
                            TextField("0.00", text: $viewModel.amountString)
                                .font(.system(size: 36, weight: .bold))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                        
                        if let error = viewModel.amountError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        // Quick amount buttons
                        HStack {
                            ForEach([10, 25, 50, 100], id: \.self) { amount in
                                Button {
                                    viewModel.amountString = "\(amount)"
                                } label: {
                                    Text("$\(amount)")
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Note Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextField("What's it for? (optional)", text: $viewModel.note)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Payment Method Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Payment Method")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ForEach(viewModel.paymentMethods, id: \.self) { method in
                            Button {
                                viewModel.selectedPaymentMethod = method
                            } label: {
                                HStack {
                                    Image(systemName: viewModel.iconForPaymentMethod(method))
                                        .foregroundColor(.blue)
                                    
                                    Text(method.rawValue)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if viewModel.selectedPaymentMethod == method {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.secondary.opacity(viewModel.selectedPaymentMethod == method ? 0.2 : 0.1))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            
            // Review Payment Button
            Button {
                viewModel.reviewPayment()
            } label: {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Review Payment")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(viewModel.isFormValid ? Color.blue : Color.gray)
            .cornerRadius(10)
            .disabled(!viewModel.isFormValid || viewModel.isProcessing)
            .padding()
        }
        .sheet(isPresented: $viewModel.showingReview) {
            SendFundsReviewView(
                amount: viewModel.amount,
                recipient: viewModel.recipientDisplay,
                note: viewModel.note,
                paymentMethod: viewModel.selectedPaymentMethod,
                onConfirm: {
                    viewModel.processFundTransfer(modelContext: modelContext)
                    viewModel.showingSuccess = true
                },
                onCancel: {
                    viewModel.showingReview = false
                }
            )
        }
        .alert("Transfer Complete", isPresented: $viewModel.showingSuccess) {
            Button("Done", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Your payment of $\(viewModel.formattedAmount) to \(viewModel.recipientDisplay) has been sent.")
        }
        .alert(item: $viewModel.error) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// Contact selector view
struct ContactSelectorView: View {
    @Binding var selectedContact: Contact?
    @State private var contacts: [Contact] = [
        Contact(id: "1", name: "John Smith", email: "john@example.com", phone: "555-123-4567"),
        Contact(id: "2", name: "Sarah Johnson", email: "sarah@example.com", phone: "555-987-6543"),
        Contact(id: "3", name: "Michael Davis", email: "michael@example.com", phone: "555-456-7890")
    ]
    @State private var searchText = ""
    
    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return contacts
        } else {
            return contacts.filter { contact in
                contact.name.localizedCaseInsensitiveContains(searchText) ||
                contact.email.localizedCaseInsensitiveContains(searchText) ||
                contact.phone.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack {
            TextField("Search contacts", text: $searchText)
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            
            List(filteredContacts) { contact in
                Button {
                    selectedContact = contact
                } label: {
                    HStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(contact.name.prefix(1)))
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            )
                        
                        VStack(alignment: .leading) {
                            Text(contact.name)
                                .font(.headline)
                            Text(contact.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedContact?.id == contact.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .listStyle(PlainListStyle())
        }
    }
}

// Review view for payment confirmation
struct SendFundsReviewView: View {
    let amount: Decimal
    let recipient: String
    let note: String
    let paymentMethod: PaymentMethod
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @State private var isConfirming = false
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section("Payment Summary") {
                        HStack {
                            Text("Amount")
                            Spacer()
                            Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue))")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("To")
                            Spacer()
                            Text(recipient)
                                .fontWeight(.semibold)
                        }
                        
                        if !note.isEmpty {
                            HStack {
                                Text("Note")
                                Spacer()
                                Text(note)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    
                    Section("Payment Method") {
                        HStack {
                            Text(paymentMethod.rawValue)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    Section("Fees") {
                        HStack {
                            Text("Transaction Fee")
                            Spacer()
                            Text("$0.00")
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Section {
                        Button {
                            isConfirming = true
                            onConfirm()
                        } label: {
                            if isConfirming {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Confirm Payment")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.white)
                            }
                        }
                        .listRowBackground(Color.blue)
                        .disabled(isConfirming)
                    }
                }
            }
            .navigationTitle("Review Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// View model for send funds functionality
class SendFundsViewModel: ObservableObject {
    @Published var selectFromContacts = false
    @Published var selectedContact: Contact?
    @Published var recipientIdentifier = ""
    @Published var amountString = ""
    @Published var note = ""
    @Published var selectedPaymentMethod: PaymentMethod = .debitCard
    @Published var isProcessing = false
    @Published var showingReview = false
    @Published var showingSuccess = false
    @Published var error: TransferError?
    
    var amountError: String? {
        if amountString.isEmpty { return nil }
        
        guard let amount = Decimal(string: amountString) else {
            return "Please enter a valid amount"
        }
        
        if amount <= 0 {
            return "Amount must be greater than zero"
        }
        
        if amount > 1000 {
            return "Amount cannot exceed $1000 per transaction"
        }
        
        return nil
    }
    
    var amount: Decimal {
        return Decimal(string: amountString) ?? 0
    }
    
    var formattedAmount: String {
        return String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue)
    }
    
    var paymentMethods: [PaymentMethod] {
        return [.debitCard, .creditCard, .bankTransfer, .wallet]
    }
    
    var isFormValid: Bool {
        let hasRecipient = selectedContact != nil || !recipientIdentifier.isEmpty
        let hasValidAmount = amount > 0 && amount <= 1000
        return hasRecipient && hasValidAmount
    }
    
    var recipientDisplay: String {
        if let contact = selectedContact {
            return contact.name
        } else {
            return recipientIdentifier
        }
    }
    
    func iconForPaymentMethod(_ method: PaymentMethod) -> String {
        switch method {
        case .debitCard: return "creditcard.fill"
        case .creditCard: return "creditcard.circle.fill"
        case .bankTransfer: return "building.columns.fill"
        case .mobileMoney: return "iphone.gen3"
        case .qrCode: return "qrcode"
        case .wallet: return "wallet.pass.fill"
        }
    }
    
    func reviewPayment() {
        showingReview = true
    }
    
    func processFundTransfer(modelContext: ModelContext) {
        isProcessing = true
        
        // Create the transaction
        let transaction = Transaction(
            amount: amount,
            status: .completed,
            type: .payment,
            paymentMethod: selectedPaymentMethod,
            transactionDescription: note.isEmpty ? nil : note,
            merchantId: "SYSTEM",
            merchantName: "Vizion Transfer",
            customerId: "CUSTOMER123", // In a real app, get from authenticated user
            customerName: "Current User", // In a real app, get from authenticated user
            reference: "TRANSFER-\(UUID().uuidString.prefix(8))"
        )
        
        modelContext.insert(transaction)
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isProcessing = false
        }
    }
}

// Models
struct Contact: Identifiable {
    let id: String
    let name: String
    let email: String
    let phone: String
}

struct TransferError: Identifiable {
    let id = UUID()
    let message: String
}

#Preview {
    SendFundsView()
        .modelContainer(for: Transaction.self, inMemory: true)
} 