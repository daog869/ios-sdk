import SwiftUI
import SwiftData
import PassKit
import Foundation
import FirebaseAuth
// Import custom views
import Vizion_Gateway

// MARK: - Main View

struct DeveloperPortalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var apiKeys: [APIKey]
    @State private var selectedEnvironment: AppEnvironment = .sandbox
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showingKeyDetail = false
    @State private var showingCreateKey = false
    @State private var selectedKey: APIKey? = nil
    @State private var selectedTab = "API Keys"
    
    var filteredKeys: [APIKey] {
        apiKeys.filter { $0.environment == selectedEnvironment }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Environment Selector
            Picker("Environment", selection: $selectedEnvironment) {
                ForEach(AppEnvironment.allCases, id: \.self) { env in
                    Text(env.displayName).tag(env)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: selectedEnvironment) { _ in
                loadAPIKeys()
            }
            
            // Tab Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(["API Keys", "Applications", "Documentation", "Quick Start", "Webhooks", "Testing"], id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(tab)
                                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .background(.bar)
            
            // Content
            TabView(selection: $selectedTab) {
                // API Keys Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("API Keys")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                showingCreateKey = true
                            }) {
                                Label("Create", systemImage: "plus")
                            }
                        }
                        .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if filteredKeys.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "key.slash")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("No API Keys")
                                    .font(.headline)
                                Text("Create your first API key to integrate with the Vizion Gateway API")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                Button(action: {
                                    showingCreateKey = true
                                }) {
                                    Text("Create API Key")
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .padding(.top)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(filteredKeys) { key in
                                    APIKeyRow(key: key, showingKeyReveal: false) {
                                        deleteAPIKey(key)
                                    }
                                    .onTapGesture {
                                        selectedKey = key
                                        showingKeyDetail = true
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .tag("API Keys")
                
                // Applications Tab
                ApplicationsView()
                    .tag("Applications")
                
                // Documentation Tab
                SDKDocumentationView()
                    .tag("Documentation")
                
                // Quick Start Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Start Guide")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        IntegrationGuideView()
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .tag("Quick Start")
                
                // Webhooks Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Webhook Configuration")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text("Coming soon...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .tag("Webhooks")
                
                // Testing Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("API Testing Tools")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        APITesterView()
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .tag("Testing")
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Developer Portal")
        .task {
            loadAPIKeys()
        }
        .sheet(isPresented: $showingCreateKey) {
            CreateAPIKeyView(onSave: { name in
                createAPIKey(name: name)
            })
        }
        .sheet(isPresented: $showingKeyDetail) {
            if let key = selectedKey {
                APIKeyDetailView(apiKey: key)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
    }
    
    private func loadAPIKeys() {
        isLoading = true
        Task {
            do {
                let keys = try await FirebaseManager.shared.getAPIKeys()
                // Filter keys by environment and update SwiftData
                let filteredKeys = keys.filter { $0.environment == selectedEnvironment }
                await MainActor.run {
                    // Clear existing keys
                    for key in apiKeys {
                        modelContext.delete(key)
                    }
                    // Add new keys
                    for key in filteredKeys {
                        modelContext.insert(key)
                    }
                    try? modelContext.save()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load API keys: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func createAPIKey(name: String) {
        isLoading = true
        Task {
            do {
                guard let currentUser = FirebaseAuth.Auth.auth().currentUser else {
                    throw NSError(domain: "AppError", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }
                
                let key = try await FirebaseManager.shared.generateAPIKey(
                    for: currentUser.uid,
                    name: name,
                    environment: selectedEnvironment
                )
                print("Generated key: \(key)")
                
                // Reload keys
                loadAPIKeys()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create API key: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func deleteAPIKey(_ key: APIKey) {
        isLoading = true
        Task {
            do {
                try await FirebaseManager.shared.deleteAPIKey(key.id)
                loadAPIKeys()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete API key: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct CreateAPIKeyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var keyName = ""
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("API Key Details") {
                    TextField("Key Name", text: $keyName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Button("Create API Key") {
                        if !keyName.isEmpty {
                            onSave(keyName)
                            dismiss()
                        }
                    }
                    .disabled(keyName.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Create API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}


// MARK: - Supporting Views

struct APIKeyDetailView: View {
    let apiKey: APIKey
    
    @State private var showingFullKey = false
    @State private var copyMessage = ""
    @State private var showCopyMessage = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(apiKey.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            // Environment badge
                            Text(apiKey.environment.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(apiKey.environment == .production ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                                .foregroundColor(apiKey.environment == .production ? .red : .green)
                                .cornerRadius(8)
                        }
                        
                        // Key display
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                if showingFullKey {
                                    Text(apiKey.key)
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                } else {
                                    Text(maskedKey)
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showingFullKey.toggle()
                                }) {
                                    Image(systemName: showingFullKey ? "eye.slash" : "eye")
                                }
                                
                                Button(action: {
                                    UIPasteboard.general.string = apiKey.key
                                    copyMessage = "API key copied to clipboard"
                                    showCopyMessage = true
                                }) {
                                    Image(systemName: "doc.on.doc")
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        Divider()
                        
                        // Creation details
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Created on \(apiKey.createdAt.formatted(date: .long, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let lastUsed = apiKey.lastUsed {
                                Text("Last used \(lastUsed.formatted(date: .long, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Implementation Example") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HTTPS Request")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("curl https://api.viziongw.com/v1/transactions \\")
                            + Text("\n  -H \"Authorization: Bearer \(apiKey.key)\" \\")
                            + Text("\n  -H \"Content-Type: application/json\" \\")
                            + Text("\n  -d '{\"amount\": 100.00, \"currency\": \"XCD\", ...}'")
                        
                        Button("Copy Example") {
                            let example = """
                            curl https://api.viziongw.com/v1/transactions \\
                              -H "Authorization: Bearer \(apiKey.key)" \\
                              -H "Content-Type: application/json" \\
                              -d '{"amount": 100.00, "currency": "XCD", ...}'
                            """
                            UIPasteboard.general.string = example
                            copyMessage = "Example code copied to clipboard"
                            showCopyMessage = true
                        }
                        .padding(.top, 8)
                    }
                    .font(.system(.body, design: .monospaced))
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("API Key Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Just dismiss
                    }
                }
            }
            .overlay {
                if showCopyMessage {
                    VStack {
                        Spacer()
                        Text(copyMessage)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 4)
                            .padding(.bottom, 32)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCopyMessage = false
                                }
                            }
                    }
                }
            }
        }
    }
    
    private var maskedKey: String {
        guard apiKey.key.count > 8 else { return apiKey.key }
        let prefix = String(apiKey.key.prefix(4))
        let suffix = String(apiKey.key.suffix(4))
        return "\(prefix)••••••••\(suffix)"
    }
}

// Create placeholder views for missing components
struct IntegrationGuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Integration Steps")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                IntegrationStep(number: 1, title: "Generate API Keys", description: "Create API keys for sandbox and production environments.")
                IntegrationStep(number: 2, title: "Install SDK", description: "Add our SDK to your project using npm, CocoaPods, or direct download.")
                IntegrationStep(number: 3, title: "Configure SDK", description: "Initialize the SDK with your API key and environment settings.")
                IntegrationStep(number: 4, title: "Implement Payment Flow", description: "Add payment processing to your application using our SDK methods.")
                IntegrationStep(number: 5, title: "Test in Sandbox", description: "Thoroughly test your integration in the sandbox environment.")
                IntegrationStep(number: 6, title: "Go Live", description: "Switch to production keys when you're ready to accept real payments.")
            }
            
            Divider()
                .padding(.vertical, 8)
            
            Text("Sample Code")
                .font(.headline)
            
            SampleCodeView()
        }
    }
}

struct IntegrationStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SampleCodeView: View {
    @State private var selectedLanguage = 0
    let languages = ["Swift", "JavaScript", "Python", "PHP"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Language", selection: $selectedLanguage) {
                ForEach(0..<languages.count, id: \.self) { index in
                    Text(languages[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            ScrollView {
                Text(sampleCode)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .frame(height: 200)
            
            Button("Copy Code") {
                UIPasteboard.general.string = sampleCode
            }
            .padding(.top, 8)
        }
    }
    
    private var sampleCode: String {
        switch languages[selectedLanguage] {
        case "Swift":
            return """
            import VizionPaySDK

            // Initialize the SDK
            VizionPay.initialize(apiKey: "vz_sk_test_YOUR_KEY")

            // Create a payment
            let payment = Payment(
                amount: 100.00,
                currency: "XCD",
                description: "Order #1234",
                customerEmail: "customer@example.com"
            )

            // Process the payment
            VizionPay.processPayment(payment) { result in
                switch result {
                case .success(let transaction):
                    print("Payment successful: \\(transaction.id)")
                case .failure(let error):
                    print("Payment failed: \\(error.localizedDescription)")
                }
            }
            """
        case "JavaScript":
            return """
            // Initialize the SDK
            const vizionPay = new VizionPay('vz_sk_test_YOUR_KEY');

            // Create a payment
            const payment = {
              amount: 100.00,
              currency: 'XCD',
              description: 'Order #1234',
              customer_email: 'customer@example.com'
            };

            // Process the payment
            vizionPay.processPayment(payment)
              .then(transaction => {
                console.log(`Payment successful: ${transaction.id}`);
              })
              .catch(error => {
                console.error(`Payment failed: ${error.message}`);
              });
            """
        case "Python":
            return """
            import vizion_pay

            # Initialize the SDK
            vizion = vizion_pay.VizionPay("vz_sk_test_YOUR_KEY")

            # Create a payment
            payment = {
                "amount": 100.00,
                "currency": "XCD",
                "description": "Order #1234",
                "customer_email": "customer@example.com"
            }

            # Process the payment
            try:
                transaction = vizion.process_payment(payment)
                print(f"Payment successful: {transaction.id}")
            except vizion_pay.VizionPayError as e:
                print(f"Payment failed: {str(e)}")
            """
        case "PHP":
            return """
            <?php
            require_once('vendor/autoload.php');

            // Initialize the SDK
            $vizionPay = new VizionPay\\Client('vz_sk_test_YOUR_KEY');

            // Create a payment
            $payment = [
                'amount' => 100.00,
                'currency' => 'XCD',
                'description' => 'Order #1234',
                'customer_email' => 'customer@example.com'
            ];

            // Process the payment
            try {
                $transaction = $vizionPay->processPayment($payment);
                echo "Payment successful: " . $transaction->id;
            } catch (VizionPay\\Exception $e) {
                echo "Payment failed: " . $e->getMessage();
            }
            ?>
            """
        default:
            return ""
        }
    }
}

struct APITesterView: View {
    @State private var endpoint = "transactions"
    @State private var method = "GET"
    @State private var requestBody = "{}"
    @State private var response = ""
    @State private var isLoading = false
    
    let endpoints = ["transactions", "customers", "webhooks", "reports"]
    let methods = ["GET", "POST", "PUT", "DELETE"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test API Requests")
                .font(.headline)
            
            // Endpoint and method
            HStack {
                Picker("Endpoint", selection: $endpoint) {
                    ForEach(endpoints, id: \.self) { endpoint in
                        Text(endpoint).tag(endpoint)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Picker("Method", selection: $method) {
                    ForEach(methods, id: \.self) { method in
                        Text(method).tag(method)
                    }
                }
                .frame(width: 100)
            }
            
            // Request body
            VStack(alignment: .leading, spacing: 8) {
                Text("Request Body")
                    .font(.subheadline)
                
                TextEditor(text: $requestBody)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            // Send button
            Button(action: sendRequest) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Send Request")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(isLoading)
            
            // Response
            VStack(alignment: .leading, spacing: 8) {
                Text("Response")
                    .font(.subheadline)
                
                ScrollView {
                    Text(response)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .frame(height: 200)
            }
        }
    }
    
    private func sendRequest() {
        isLoading = true
        
        // Simulate API request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let responses = [
                "transactions": """
                {
                  "success": true,
                  "data": {
                    "transactions": [
                      {
                        "id": "tr_12345",
                        "amount": 100.00,
                        "currency": "XCD",
                        "status": "completed",
                        "created_at": "2025-01-15T14:30:23Z"
                      }
                    ]
                  }
                }
                """,
                "customers": """
                {
                  "success": true,
                  "data": {
                    "customers": [
                      {
                        "id": "cus_12345",
                        "email": "customer@example.com",
                        "name": "John Doe",
                        "created_at": "2025-01-10T09:15:43Z"
                      }
                    ]
                  }
                }
                """,
                "webhooks": """
                {
                  "success": true,
                  "data": {
                    "webhooks": [
                      {
                        "id": "wh_12345",
                        "url": "https://example.com/webhooks",
                        "events": ["transaction.completed", "transaction.failed"],
                        "created_at": "2025-01-05T11:22:33Z"
                      }
                    ]
                  }
                }
                """,
                "reports": """
                {
                  "success": true,
                  "data": {
                    "reports": [
                      {
                        "id": "rep_12345",
                        "type": "monthly",
                        "date": "2025-01-01",
                        "url": "https://api.viziongw.com/reports/rep_12345.pdf"
                      }
                    ]
                  }
                }
                """
            ]
            
            response = responses[endpoint] ?? "{\"error\": \"Unknown endpoint\"}"
            isLoading = false
        }
    }
}

// MARK: - Documentation Views

struct SDKGuideView: View {
    var body: some View {
        List {
            Section("Getting Started") {
                NavigationLink("Installation") {
                    MarkdownContentView(fileName: "sdk_installation")
                }
                NavigationLink("Configuration") {
                    MarkdownContentView(fileName: "sdk_configuration")
                }
                NavigationLink("Quick Start") {
                    MarkdownContentView(fileName: "sdk_quickstart")
                }
            }
            
            Section("Integration Guides") {
                NavigationLink("Payment Processing") {
                    MarkdownContentView(fileName: "sdk_payments")
                }
                NavigationLink("Customer Management") {
                    MarkdownContentView(fileName: "sdk_customers")
                }
                NavigationLink("Error Handling") {
                    MarkdownContentView(fileName: "sdk_errors")
                }
            }
        }
        .navigationTitle("SDK Documentation")
    }
}

struct WebhookGuideView: View {
    var body: some View {
        List {
            Section("Overview") {
                NavigationLink("Introduction") {
                    MarkdownContentView(fileName: "webhook_intro")
                }
                NavigationLink("Security") {
                    MarkdownContentView(fileName: "webhook_security")
                }
            }
            
            Section("Event Types") {
                NavigationLink("Payment Events") {
                    MarkdownContentView(fileName: "webhook_payment_events")
                }
                NavigationLink("Customer Events") {
                    MarkdownContentView(fileName: "webhook_customer_events")
                }
                NavigationLink("Dispute Events") {
                    MarkdownContentView(fileName: "webhook_dispute_events")
                }
            }
        }
        .navigationTitle("Webhook Documentation")
    }
}

// Additional Views

struct WebhookEndpointRow: View {
    let webhook: WebhookEndpoint
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(webhook.url)
                    .font(.headline)
                Spacer()
                Text(webhook.isActive ? "Active" : "Inactive")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(webhook.isActive ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .foregroundStyle(webhook.isActive ? .green : .red)
                    .clipShape(Capsule())
            }
            
            Text("Events: \(webhook.events.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("Created: \(webhook.createdAt.formatted())")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct APIDocumentationView: View {
    @State private var content = ""
    
    var body: some View {
        ScrollView {
            if content.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 50)
            } else {
                Text(.init(content))
                    .padding()
            }
        }
        .navigationTitle("API Documentation")
        .task {
            if let url = Bundle.main.url(forResource: "api_reference", withExtension: "md"),
               let markdown = try? String(contentsOf: url) {
                content = markdown
            }
        }
    }
}

struct MarkdownContentView: View {
    let fileName: String
    @State private var content = ""
    
    var body: some View {
        ScrollView {
            Text(content)
                .padding()
        }
        .onAppear {
            // Load markdown content
            content = "Documentation content will be loaded here"
        }
    }
}

// Notification extension for environment changes
extension Notification.Name {
    static let environmentChanged = Notification.Name("environmentChanged")
}

// Preview
#Preview {
    NavigationView {
        DeveloperPortalView()
    }
} 

