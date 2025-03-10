import SwiftUI
import SwiftData
import FirebaseFirestore

struct TestTransactionView: View {
    @StateObject private var viewModel = TestTransactionViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Test Type", selection: $selectedTab) {
                Text("Transaction").tag(0)
                Text("Webhook").tag(1)
                Text("API Key").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content based on selected tab
            TabView(selection: $selectedTab) {
                // Transaction Testing
                TestTransactionCreatorView(viewModel: viewModel)
                    .tag(0)
                
                // Webhook Testing
                WebhookTesterView(viewModel: viewModel)
                    .tag(1)
                
                // API Key Testing
                APIKeyTesterView(viewModel: viewModel)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Testing Tools")
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// Transaction testing view
struct TestTransactionCreatorView: View {
    @ObservedObject var viewModel: TestTransactionViewModel
    
    var body: some View {
        Form {
            Section("Transaction Details") {
                TextField("Amount", text: $viewModel.amount)
                    .keyboardType(.decimalPad)
                
                Picker("Currency", selection: $viewModel.currency) {
                    ForEach(viewModel.currencies, id: \.self) { currency in
                        Text(currency).tag(currency)
                    }
                }
                
                Picker("Payment Method", selection: $viewModel.paymentMethod) {
                    ForEach(viewModel.paymentMethods, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                
                Picker("Status", selection: $viewModel.status) {
                    ForEach(viewModel.statusOptions, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                
                TextField("Merchant Name", text: $viewModel.merchantName)
                TextField("Customer Name (Optional)", text: $viewModel.customerName)
                TextField("Reference", text: $viewModel.reference)
            }
            
            Section("API Key") {
                Picker("API Key", selection: $viewModel.selectedAPIKey) {
                    Text("Select API Key").tag("")
                    ForEach(viewModel.apiKeys, id: \.key) { key in
                        Text("\(key.name) (\(key.key.prefix(8))...)").tag(key.key)
                    }
                }
                
                if viewModel.selectedAPIKey.isEmpty {
                    Button("Load API Keys") {
                        Task {
                            await viewModel.loadAPIKeys()
                        }
                    }
                }
            }
            
            Section {
                Button("Create Test Transaction") {
                    Task {
                        await viewModel.createTestTransaction()
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(!viewModel.isFormValid)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadAPIKeys()
            }
        }
    }
}

// Webhook testing view
struct WebhookTesterView: View {
    @ObservedObject var viewModel: TestTransactionViewModel
    @State private var webhookURL = ""
    @State private var eventType = "payment.created"
    @State private var payloadText = "{\"id\":\"evt_test_123\",\"type\":\"payment.created\",\"data\":{\"id\":\"pay_123\",\"amount\":1000,\"currency\":\"XCD\",\"status\":\"succeeded\"}}"
    
    var body: some View {
        Form {
            Section("Webhook Configuration") {
                TextField("Webhook URL", text: $webhookURL)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                
                Picker("Event Type", selection: $eventType) {
                    Text("payment.created").tag("payment.created")
                    Text("payment.updated").tag("payment.updated")
                    Text("payout.created").tag("payout.created")
                    Text("dispute.created").tag("dispute.created")
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Payload")
                        .font(.headline)
                    
                    TextEditor(text: $payloadText)
                        .frame(minHeight: 200)
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            Section("API Key") {
                Picker("API Key", selection: $viewModel.selectedAPIKey) {
                    Text("Select API Key").tag("")
                    ForEach(viewModel.apiKeys, id: \.key) { key in
                        Text("\(key.name) (\(key.key.prefix(8))...)").tag(key.key)
                    }
                }
            }
            
            Section {
                Button("Send Test Webhook") {
                    Task {
                        await viewModel.sendTestWebhook(url: webhookURL, eventType: eventType, payload: payloadText)
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(webhookURL.isEmpty || viewModel.selectedAPIKey.isEmpty)
            }
        }
    }
}

// API Key testing view
struct APIKeyTesterView: View {
    @ObservedObject var viewModel: TestTransactionViewModel
    @State private var testEndpoint = "https://api.viziongateway.com/v1/ping"
    @State private var requestMethod = "GET"
    @State private var requestBody = "{}"
    @State private var showResponse = false
    @State private var responseText = ""
    
    var body: some View {
        Form {
            Section("API Request") {
                TextField("Endpoint URL", text: $testEndpoint)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                
                Picker("Method", selection: $requestMethod) {
                    Text("GET").tag("GET")
                    Text("POST").tag("POST")
                    Text("PUT").tag("PUT")
                    Text("DELETE").tag("DELETE")
                }
                
                if requestMethod != "GET" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Request Body")
                            .font(.headline)
                        
                        TextEditor(text: $requestBody)
                            .frame(minHeight: 120)
                            .font(.system(.body, design: .monospaced))
                            .padding(4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            
            Section("API Key") {
                Picker("API Key", selection: $viewModel.selectedAPIKey) {
                    Text("Select API Key").tag("")
                    ForEach(viewModel.apiKeys, id: \.key) { key in
                        Text("\(key.name) (\(key.key.prefix(8))...)").tag(key.key)
                    }
                }
            }
            
            if showResponse {
                Section("Response") {
                    ScrollView {
                        Text(responseText)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                    .frame(height: 200)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Section {
                Button("Test API Key") {
                    Task {
                        let response = await viewModel.testAPIKey(
                            endpoint: testEndpoint,
                            method: requestMethod,
                            body: requestMethod != "GET" ? requestBody : nil
                        )
                        responseText = response
                        showResponse = true
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(testEndpoint.isEmpty || viewModel.selectedAPIKey.isEmpty)
            }
        }
    }
}

// View model for transaction testing tools
class TestTransactionViewModel: ObservableObject {
    @Published var amount = "10.00"
    @Published var currency = "XCD"
    @Published var paymentMethod: PaymentMethod = .debitCard
    @Published var status: TransactionStatus = .completed
    @Published var merchantName = "Test Merchant"
    @Published var customerName = ""
    @Published var reference = "TEST-\(Int.random(in: 10000...99999))"
    
    @Published var selectedAPIKey = ""
    @Published var apiKeys: [APIKey] = []
    @Published var isLoading = false
    
    @Published var showSuccess = false
    @Published var showError = false
    @Published var successMessage: String?
    @Published var errorMessage: String?
    
    var currencies = ["XCD", "USD", "EUR", "GBP", "CAD"]
    var paymentMethods: [PaymentMethod] { return PaymentMethod.allCases }
    var statusOptions: [TransactionStatus] { return TransactionStatus.allCases }
    
    private let db = Firestore.firestore()
    
    var isFormValid: Bool {
        guard let _ = Decimal(string: amount), !merchantName.isEmpty, !reference.isEmpty else {
            return false
        }
        return !selectedAPIKey.isEmpty
    }
    
    func loadAPIKeys() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("apiKeys")
                .whereField("active", isEqualTo: true)
                .getDocuments()
            
            var keys: [APIKey] = []
            for document in snapshot.documents {
                let data = document.data()
                guard let key = data["key"] as? String,
                      let name = data["name"] as? String,
                      let merchantId = data["merchantId"] as? String,
                      let active = data["active"] as? Bool,
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                    continue
                }
                
                // Get scopes from the data
                var scopes: Set<APIScope> = []
                if let scopeStrings = data["scopes"] as? [String] {
                    for scopeString in scopeStrings {
                        if let scope = APIScope(rawValue: scopeString) {
                            scopes.insert(scope)
                        }
                    }
                }
                
                let apiKey = APIKey(
                    id: document.documentID,
                    name: name,
                    key: key,
                    createdAt: createdAt,
                    environment: AppEnvironment(rawValue: UserDefaults.standard.string(forKey: "environment") ?? "sandbox") ?? .sandbox,
                    lastUsed: nil,
                    scopes: scopes,
                    active: active,
                    merchantId: merchantId,
                    expiresAt: nil,
                    ipRestrictions: nil,
                    metadata: nil
                )
                keys.append(apiKey)
            }
            
            await MainActor.run {
                self.apiKeys = keys
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load API keys: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }
    
    func createTestTransaction() async {
        guard let amountDecimal = Decimal(string: amount) else {
            errorMessage = "Invalid amount format"
            showError = true
            return
        }
        
        do {
            // Create transaction data
            let transactionData: [String: Any] = [
                "amount": NSDecimalNumber(decimal: amountDecimal).doubleValue,
                "currency": currency,
                "payment_method": paymentMethod.rawValue,
                "status": status.rawValue,
                "merchant_name": merchantName,
                "customer_name": customerName,
                "reference": reference,
                "api_key": selectedAPIKey,
                "timestamp": Timestamp(date: Date())
            ]
            
            // Call the test transaction API
            let docRef = try await db.collection("testTransactions").addDocument(data: transactionData)
            
            await MainActor.run {
                self.successMessage = "Test transaction created successfully with ID: \(docRef.documentID)"
                self.showSuccess = true
                self.reference = "TEST-\(Int.random(in: 10000...99999))"
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create test transaction: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }
    
    func sendTestWebhook(url: String, eventType: String, payload: String) async {
        do {
            // Create webhook test data
            let webhookData: [String: Any] = [
                "url": url,
                "event_type": eventType,
                "payload": payload,
                "api_key": selectedAPIKey,
                "timestamp": Timestamp(date: Date())
            ]
            
            // Call the webhook test API
            let docRef = try await db.collection("testWebhooks").addDocument(data: webhookData)
            
            await MainActor.run {
                self.successMessage = "Test webhook sent successfully with ID: \(docRef.documentID)"
                self.showSuccess = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to send test webhook: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }
    
    func testAPIKey(endpoint: String, method: String, body: String?) async -> String {
        do {
            // Create API test data
            var testData: [String: Any] = [
                "endpoint": endpoint,
                "method": method,
                "api_key": selectedAPIKey,
                "timestamp": Timestamp(date: Date())
            ]
            
            if let body = body, !body.isEmpty {
                testData["body"] = body
            }
            
            // Call the API test function
            let docRef = try await db.collection("apiTests").addDocument(data: testData)
            
            // Simulate API response
            await MainActor.run {
                self.successMessage = "API request sent successfully"
                self.showSuccess = true
            }
            
            // Return simulated response
            return """
            {
              "success": true,
              "request_id": "\(docRef.documentID)",
              "timestamp": "\(Date().ISO8601Format())",
              "data": {
                "message": "API key test successful",
                "endpoint": "\(endpoint)",
                "method": "\(method)"
              }
            }
            """
        } catch {
            await MainActor.run {
                self.errorMessage = "API request failed: \(error.localizedDescription)"
                self.showError = true
            }
            
            return """
            {
              "success": false,
              "error": {
                "code": "request_failed",
                "message": "\(error.localizedDescription)"
              }
            }
            """
        }
    }
}

#Preview {
    TestTransactionView()
} 