import SwiftUI

struct SDKDocumentationView: View {
    @State private var selectedTopic: DocumentationTopic?
    @State private var showingTopic = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("SDK Documentation")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom)
                
                // Getting Started Section
                VStack(alignment: .leading, spacing: 0) {
                    Text("GETTING STARTED")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    DocumentationSection(
                        topics: [
                            DocumentationTopic(title: "Installation", 
                                              content: installationContent,
                                              type: .gettingStarted),
                            DocumentationTopic(title: "Configuration", 
                                              content: configurationContent,
                                              type: .gettingStarted),
                            DocumentationTopic(title: "Quick Start", 
                                              content: quickStartContent,
                                              type: .gettingStarted)
                        ],
                        selectedTopic: $selectedTopic,
                        showingTopic: $showingTopic
                    )
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Integration Guides Section
                VStack(alignment: .leading, spacing: 0) {
                    Text("INTEGRATION GUIDES")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    DocumentationSection(
                        topics: [
                            DocumentationTopic(title: "Payment Processing", 
                                              content: paymentProcessingContent,
                                              type: .integrationGuide),
                            DocumentationTopic(title: "Customer Management", 
                                              content: customerManagementContent,
                                              type: .integrationGuide),
                            DocumentationTopic(title: "Error Handling", 
                                              content: errorHandlingContent,
                                              type: .integrationGuide)
                        ],
                        selectedTopic: $selectedTopic,
                        showingTopic: $showingTopic
                    )
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // API Reference Section
                VStack(alignment: .leading, spacing: 0) {
                    Text("API REFERENCE")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    DocumentationSection(
                        topics: [
                            DocumentationTopic(title: "Transactions API", 
                                              content: transactionsAPIContent,
                                              type: .apiReference),
                            DocumentationTopic(title: "Customers API", 
                                              content: customersAPIContent,
                                              type: .apiReference),
                            DocumentationTopic(title: "Webhooks API", 
                                              content: webhooksAPIContent,
                                              type: .apiReference),
                            DocumentationTopic(title: "Reports API", 
                                              content: reportsAPIContent,
                                              type: .apiReference)
                        ],
                        selectedTopic: $selectedTopic,
                        showingTopic: $showingTopic
                    )
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Advanced Topics Section
                VStack(alignment: .leading, spacing: 0) {
                    Text("ADVANCED TOPICS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    DocumentationSection(
                        topics: [
                            DocumentationTopic(title: "Security Best Practices", 
                                              content: securityContent,
                                              type: .advanced),
                            DocumentationTopic(title: "Handling Webhooks", 
                                              content: handlingWebhooksContent,
                                              type: .advanced),
                            DocumentationTopic(title: "Testing and Debugging", 
                                              content: testingContent,
                                              type: .advanced),
                            DocumentationTopic(title: "Going to Production", 
                                              content: productionContent,
                                              type: .advanced)
                        ],
                        selectedTopic: $selectedTopic,
                        showingTopic: $showingTopic
                    )
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Documentation")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingTopic) {
            if let topic = selectedTopic {
                DocumentationDetailView(topic: topic)
            }
        }
    }
    
    // MARK: - Documentation Content
    
    // Getting Started Content
    private var installationContent: String {
        """
        # Installation
        
        The Vizion Gateway SDK can be installed through Swift Package Manager.
        
        ## Swift Package Manager
        
        Add the following to your Package.swift:
        
        ```swift
        dependencies: [
            .package(url: "https://github.com/daog869/ios-sdk.git", from: "1.0.0")
        ]
        ```
        
        Or in Xcode:
        
        1. Go to File > Add Packages...
        2. Enter: https://github.com/daog869/ios-sdk.git
        3. Click "Add Package"
        """
    }
    
    private var configurationContent: String {
        """
        # Configuration
        
        Before using the Vizion Gateway SDK, you need to configure it with your API key and other settings.
        
        ## Basic Configuration
        
        ```swift
        import VizionGatewaySDK
        
        // In your AppDelegate or early in your app's lifecycle
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
            // Initialize the SDK
            VizionGateway.initialize(
                apiKey: "your_api_key_here",
                environment: .sandbox // or .production for live payments
            )
            
            return true
        }
        ```
        
        ## Advanced Configuration
        
        You can customize the SDK behavior with additional options:
        
        ```swift
        let config = VizionGatewayConfig(
            apiKey: "your_api_key_here",
            environment: .sandbox,
            loggingEnabled: true,
            timeout: 30.0, // in seconds
            merchantId: "your_merchant_id"
        )
        
        VizionGateway.initialize(with: config)
        ```
        """
    }
    
    private var quickStartContent: String {
        """
        # Quick Start
        
        Follow these steps to quickly integrate payment processing in your app:
        
        ## 1. Initialize the SDK
        
        ```swift
        import VizionGatewaySDK
        
        // Initialize the SDK
        VizionGateway.initialize(apiKey: "your_api_key_here")
        ```
        
        ## 2. Create a Payment
        
        ```swift
        let payment = Payment(
            amount: 100.00,
            currency: "XCD",
            description: "Order #1234",
            customerEmail: "customer@example.com"
        )
        ```
        
        ## 3. Process the Payment
        
        ```swift
        VizionGateway.processPayment(payment) { result in
            switch result {
            case .success(let transaction):
                print("Payment successful: \\(transaction.id)")
            case .failure(let error):
                print("Payment failed: \\(error.localizedDescription)")
            }
        }
        ```
        
        ## 4. Handle the Result
        
        Display appropriate UI based on the payment result:
        
        ```swift
        if transaction.status == .completed {
            showSuccessScreen(transaction: transaction)
        } else {
            showErrorScreen(message: "Payment could not be completed")
        }
        ```
        """
    }
    
    // Integration Guides Content
    private var paymentProcessingContent: String {
        """
        # Payment Processing
        
        Learn how to process different types of payments with the Vizion Gateway SDK.
        
        ## Card Payments
        
        ```swift
        // Create a card payment
        let card = Card(
            number: "4242424242424242",
            expiryMonth: 12,
            expiryYear: 2025,
            cvc: "123",
            name: "John Doe"
        )
        
        let payment = CardPayment(
            amount: 100.00,
            currency: "XCD",
            card: card,
            description: "Card payment for Order #1234"
        )
        
        // Process the payment
        VizionGateway.processCardPayment(payment) { result in
            // Handle result
        }
        ```
        
        ## Bank Transfers
        
        ```swift
        // Create a bank transfer payment
        let bankDetails = BankDetails(
            accountNumber: "000123456789",
            routingNumber: "021000021",
            accountHolderName: "John Doe",
            accountType: .checking
        )
        
        let payment = BankTransferPayment(
            amount: 500.00,
            currency: "XCD",
            bankDetails: bankDetails,
            description: "Invoice #5678"
        )
        
        // Process the bank transfer
        VizionGateway.processBankTransfer(payment) { result in
            // Handle result
        }
        ```
        
        ## Mobile Money
        
        ```swift
        // Create a mobile money payment
        let mobileMoneyPayment = MobileMoneyPayment(
            amount: 50.00,
            currency: "XCD",
            phoneNumber: "+1758123456789",
            provider: .flow,
            description: "Mobile payment"
        )
        
        // Process the mobile money payment
        VizionGateway.processMobileMoneyPayment(mobileMoneyPayment) { result in
            // Handle result
        }
        ```
        """
    }
    
    private var customerManagementContent: String {
        """
        # Customer Management
        
        Learn how to manage customers and store payment methods for future use.
        
        ## Creating a Customer
        
        ```swift
        let customer = Customer(
            email: "customer@example.com",
            name: "John Doe",
            phone: "+1758123456789",
            address: Address(
                line1: "123 Main St",
                line2: "Apt 4B",
                city: "Castries",
                state: "LC",
                postalCode: "12345",
                country: "LC"
            )
        )
        
        VizionGateway.createCustomer(customer) { result in
            switch result {
            case .success(let createdCustomer):
                print("Customer created: \\(createdCustomer.id)")
            case .failure(let error):
                print("Failed to create customer: \\(error.localizedDescription)")
            }
        }
        ```
        
        ## Adding a Payment Method to a Customer
        
        ```swift
        // Create a card
        let card = Card(
            number: "4242424242424242",
            expiryMonth: 12,
            expiryYear: 2025,
            cvc: "123",
            name: "John Doe"
        )
        
        VizionGateway.addPaymentMethod(
            card,
            toCustomer: "cus_12345",
            makeDefault: true
        ) { result in
            switch result {
            case .success(let paymentMethod):
                print("Payment method added: \\(paymentMethod.id)")
            case .failure(let error):
                print("Failed to add payment method: \\(error.localizedDescription)")
            }
        }
        ```
        
        ## Charging a Customer
        
        ```swift
        // Charge a customer's default payment method
        VizionGateway.chargeCustomer(
            customerId: "cus_12345",
            amount: 100.00,
            currency: "XCD",
            description: "Subscription renewal"
        ) { result in
            switch result {
            case .success(let transaction):
                print("Customer charged: \\(transaction.id)")
            case .failure(let error):
                print("Failed to charge customer: \\(error.localizedDescription)")
            }
        }
        ```
        """
    }
    
    private var errorHandlingContent: String {
        """
        # Error Handling
        
        Learn how to handle errors and edge cases when using the Vizion Gateway SDK.
        
        ## Error Types
        
        The SDK uses a structured error system to help you handle different types of errors:
        
        ```swift
        public enum VizionGatewayError: Error {
            case networkError(Error)
            case serverError(statusCode: Int, message: String)
            case authenticationError(message: String)
            case validationError(fields: [String: String])
            case processingError(code: String, message: String)
            case cardDeclined(reason: String?)
            case insufficientFunds
            case fraudSuspected
            case riskRejection
            case unknownError(Error)
        }
        ```
        
        ## Handling Specific Errors
        
        ```swift
        VizionGateway.processPayment(payment) { result in
            switch result {
            case .success(let transaction):
                showSuccessScreen(transaction: transaction)
                
            case .failure(let error):
                switch error {
                case .networkError:
                    showErrorMessage("Connection issue. Please check your internet connection and try again.")
                    
                case .cardDeclined(let reason):
                    showErrorMessage("Card declined: \\(reason ?? "Unknown reason")")
                    
                case .insufficientFunds:
                    showErrorMessage("Insufficient funds. Please try another payment method.")
                    
                case .validationError(let fields):
                    handleValidationErrors(fields)
                    
                default:
                    showErrorMessage("Payment failed: \\(error.localizedDescription)")
                }
            }
        }
        ```
        
        ## Error Recovery Strategies
        
        For transient errors like network issues, implement a retry mechanism:
        
        ```swift
        func processPaymentWithRetry(payment: Payment, maxRetries: Int = 3) {
            var retries = 0
            
            func attempt() {
                VizionGateway.processPayment(payment) { result in
                    switch result {
                    case .success(let transaction):
                        handleSuccessfulPayment(transaction)
                        
                    case .failure(let error):
                        if case .networkError = error, retries < maxRetries {
                            retries += 1
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                attempt()
                            }
                        } else {
                            handlePaymentError(error)
                        }
                    }
                }
            }
            
            attempt()
        }
        ```
        """
    }
    
    // API Reference Content
    private var transactionsAPIContent: String {
        """
        # Transactions API
        
        Reference documentation for the Transactions API methods.
        
        ## Create a Transaction
        
        ```swift
        // Basic transaction
        let transaction = Transaction(
            amount: 100.00,
            currency: "XCD",
            paymentMethod: paymentMethod,
            description: "Order #1234"
        )
        
        VizionGateway.transactions.create(transaction) { result in
            // Handle result
        }
        ```
        
        ## List Transactions
        
        ```swift
        // List transactions with filters
        let filters = TransactionFilters(
            limit: 10,
            offset: 0,
            dateFrom: Date().addingTimeInterval(-30*24*60*60), // Last 30 days
            dateTo: Date(),
            status: .completed
        )
        
        VizionGateway.transactions.list(filters: filters) { result in
            switch result {
            case .success(let response):
                let transactions = response.data
                let total = response.meta.total
                // Update UI with transactions
            case .failure(let error):
                // Handle error
            }
        }
        ```
        
        ## Retrieve a Transaction
        
        ```swift
        // Get transaction by ID
        VizionGateway.transactions.retrieve(id: "tx_12345") { result in
            switch result {
            case .success(let transaction):
                // Use transaction details
            case .failure(let error):
                // Handle error
            }
        }
        ```
        
        ## Update a Transaction
        
        ```swift
        // Update transaction metadata
        VizionGateway.transactions.update(
            id: "tx_12345",
            metadata: ["order_id": "ORD-5678", "customer_reference": "REF-9012"]
        ) { result in
            // Handle result
        }
        ```
        
        ## Refund a Transaction
        
        ```swift
        // Full refund
        VizionGateway.transactions.refund(id: "tx_12345") { result in
            // Handle result
        }
        
        // Partial refund
        VizionGateway.transactions.refund(
            id: "tx_12345",
            amount: 50.00,
            reason: "Customer request"
        ) { result in
            // Handle result
        }
        ```
        """
    }
    
    private var customersAPIContent: String {
        """
        # Customers API
        
        Reference documentation for the Customers API methods.
        
        ## Create a Customer
        
        ```swift
        let customer = Customer(
            email: "customer@example.com",
            name: "John Doe",
            phone: "+1758123456789"
        )
        
        VizionGateway.customers.create(customer) { result in
            // Handle result
        }
        ```
        
        ## List Customers
        
        ```swift
        let filters = CustomerFilters(
            limit: 20,
            offset: 0,
            email: "customer@example.com" // Optional filter
        )
        
        VizionGateway.customers.list(filters: filters) { result in
            // Handle result
        }
        ```
        
        ## Retrieve a Customer
        
        ```swift
        VizionGateway.customers.retrieve(id: "cus_12345") { result in
            // Handle result
        }
        ```
        
        ## Update a Customer
        
        ```swift
        let updates = CustomerUpdateParams(
            email: "newemail@example.com",
            name: "John Smith",
            phone: "+1758987654321"
        )
        
        VizionGateway.customers.update(id: "cus_12345", params: updates) { result in
            // Handle result
        }
        ```
        
        ## Delete a Customer
        
        ```swift
        VizionGateway.customers.delete(id: "cus_12345") { result in
            // Handle result
        }
        ```
        
        ## Payment Methods
        
        ```swift
        // Add payment method
        VizionGateway.customers.addPaymentMethod(
            customerId: "cus_12345",
            paymentMethod: paymentMethod
        ) { result in
            // Handle result
        }
        
        // List payment methods
        VizionGateway.customers.listPaymentMethods(customerId: "cus_12345") { result in
            // Handle result
        }
        
        // Set default payment method
        VizionGateway.customers.setDefaultPaymentMethod(
            customerId: "cus_12345",
            paymentMethodId: "pm_12345"
        ) { result in
            // Handle result
        }
        ```
        """
    }
    
    private var webhooksAPIContent: String {
        """
        # Webhooks API
        
        Reference documentation for the Webhooks API methods.
        
        ## Create a Webhook Endpoint
        
        ```swift
        let webhook = WebhookEndpoint(
            url: "https://example.com/webhooks",
            events: [.paymentCreated, .paymentUpdated, .refundCreated],
            description: "Main webhook for our app",
            enabled: true
        )
        
        VizionGateway.webhooks.create(webhook) { result in
            // Handle result
        }
        ```
        
        ## List Webhook Endpoints
        
        ```swift
        VizionGateway.webhooks.list { result in
            // Handle result
        }
        ```
        
        ## Retrieve a Webhook Endpoint
        
        ```swift
        VizionGateway.webhooks.retrieve(id: "we_12345") { result in
            // Handle result
        }
        ```
        
        ## Update a Webhook Endpoint
        
        ```swift
        let updates = WebhookUpdateParams(
            url: "https://newurl.example.com/webhooks",
            events: [.paymentCreated, .paymentUpdated, .disputeCreated],
            description: "Updated webhook endpoint",
            enabled: true
        )
        
        VizionGateway.webhooks.update(id: "we_12345", params: updates) { result in
            // Handle result
        }
        ```
        
        ## Delete a Webhook Endpoint
        
        ```swift
        VizionGateway.webhooks.delete(id: "we_12345") { result in
            // Handle result
        }
        ```
        
        ## Testing Webhooks
        
        ```swift
        // Send a test event to your webhook endpoint
        VizionGateway.webhooks.sendTestEvent(
            endpointId: "we_12345",
            event: .paymentCreated
        ) { result in
            // Handle result
        }
        ```
        """
    }
    
    private var reportsAPIContent: String {
        """
        # Reports API
        
        Reference documentation for the Reports API methods.
        
        ## Create a Report
        
        ```swift
        let report = Report(
            type: .transactions,
            dateRange: .custom(from: startDate, to: endDate),
            format: .csv
        )
        
        VizionGateway.reports.create(report) { result in
            // Handle result
        }
        ```
        
        ## List Reports
        
        ```swift
        VizionGateway.reports.list { result in
            // Handle result
        }
        ```
        
        ## Retrieve a Report
        
        ```swift
        VizionGateway.reports.retrieve(id: "rep_12345") { result in
            // Handle result
        }
        ```
        
        ## Report Types
        
        The SDK supports the following report types:
        
        - `.transactions`: List of all transactions in the specified period
        - `.settlements`: Settlement reports for the specified period
        - `.disputes`: Dispute activity for the specified period
        - `.fees`: Fee breakdown for the specified period
        
        ## Report Formats
        
        Reports can be generated in the following formats:
        
        - `.csv`: Comma-separated values file
        - `.json`: JSON data format
        - `.pdf`: PDF document format
        
        ## Downloading Reports
        
        ```swift
        VizionGateway.reports.download(id: "rep_12345") { result in
            switch result {
            case .success(let fileURL):
                // Handle the downloaded file
            case .failure(let error):
                // Handle error
            }
        }
        ```
        """
    }
    
    // Advanced Topics Content
    private var securityContent: String {
        """
        # Security Best Practices
        
        Guidelines for securely integrating the Vizion Gateway SDK.
        
        ## API Key Security
        
        Never hardcode your API keys in your application:
        
        ```swift
        // DON'T do this
        let apiKey = "sk_live_abc123..."
        
        // DO use a secure method to fetch API keys
        func getAPIKey() -> String {
            // Fetch from secure storage or backend service
            return SecureKeyManager.getKey()
        }
        ```
        
        ## Handling Sensitive Data
        
        - Never store full card details in your application
        - Use the SDK's tokenization features to avoid handling sensitive data
        - Clear sensitive data from memory when no longer needed
        
        ```swift
        func securelyProcessPayment() {
            // Tokenize the card first
            VizionGateway.tokenizeCard(card) { result in
                switch result {
                case .success(let token):
                    // Use the token for payment
                    processPaymentWithToken(token)
                    
                    // Clear sensitive data
                    card.clearSensitiveData()
                    
                case .failure(let error):
                    handleError(error)
                }
            }
        }
        ```
        
        ## Certificate Pinning
        
        Enable certificate pinning for additional security:
        
        ```swift
        let config = VizionGatewayConfig(
            apiKey: getAPIKey(),
            environment: .production,
            certificatePinning: true
        )
        
        VizionGateway.initialize(with: config)
        ```
        
        ## Environment Segregation
        
        Keep your sandbox and production environments completely separate:
        
        ```swift
        #if DEBUG
        let environment: VizionGateway.Environment = .sandbox
        #else
        let environment: VizionGateway.Environment = .production
        #endif
        
        VizionGateway.initialize(
            apiKey: getAPIKey(for: environment),
            environment: environment
        )
        ```
        """
    }
    
    private var handlingWebhooksContent: String {
        """
        # Handling Webhooks
        
        Learn how to process webhooks from Vizion Gateway in your backend.
        
        ## Webhook Verification
        
        Always verify webhook signatures to ensure they came from Vizion Gateway:
        
        ```swift
        // Server-side code (Node.js example)
        const crypto = require('crypto');
        
        function verifyWebhookSignature(payload, signature, secret) {
          const hmac = crypto.createHmac('sha256', secret);
          const digest = hmac.update(payload).digest('hex');
          return crypto.timingSafeEqual(
            Buffer.from(digest),
            Buffer.from(signature)
          );
        }
        
        // In your webhook handler
        app.post('/webhooks', (req, res) => {
          const signature = req.headers['vizion-signature'];
          const isValid = verifyWebhookSignature(
            JSON.stringify(req.body),
            signature,
            process.env.WEBHOOK_SECRET
          );
          
          if (!isValid) {
            return res.status(401).send('Invalid signature');
          }
          
          // Process the webhook
          handleWebhookEvent(req.body);
          res.status(200).send('Webhook received');
        });
        ```
        
        ## Event Types
        
        Handle different event types appropriately:
        
        ```swift
        function handleWebhookEvent(event) {
          switch (event.type) {
            case 'payment.succeeded':
              updateOrderStatus(event.data.id);
              break;
              
            case 'payment.failed':
              notifyCustomerOfFailure(event.data);
              break;
              
            case 'refund.created':
              processRefund(event.data);
              break;
              
            // Handle other event types
              
            default:
              console.log(`Unhandled event type: ${event.type}`);
          }
        }
        ```
        
        ## Webhook Idempotency
        
        Implement idempotency to handle duplicate webhook deliveries:
        
        ```swift
        async function processWebhook(event) {
          // Check if we've already processed this event
          const eventId = event.id;
          const processed = await db.events.findOne({ id: eventId });
          
          if (processed) {
            return; // Skip processing
          }
          
          // Process the webhook event
          await handleWebhookEvent(event);
          
          // Mark as processed
          await db.events.insert({ id: eventId, processedAt: new Date() });
        }
        ```
        """
    }
    
    private var testingContent: String {
        """
        # Testing and Debugging
        
        Tools and techniques for testing your Vizion Gateway integration.
        
        ## Sandbox Environment
        
        Always use the sandbox environment for testing:
        
        ```swift
        VizionGateway.initialize(
            apiKey: "sk_test_your_test_key",
            environment: .sandbox
        )
        ```
        
        ## Test Cards
        
        Use these test cards to simulate different scenarios:
        
        | Card Number | Scenario |
        |-------------|----------|
        | 4242424242424242 | Successful payment |
        | 4000000000000002 | Declined payment |
        | 4000000000000127 | Insufficient funds |
        | 4000000000000069 | Expired card |
        | 4000000000000101 | 3D Secure required |
        
        ```swift
        // Test a successful payment
        let testCard = Card(
            number: "4242424242424242",
            expiryMonth: 12,
            expiryYear: 2030,
            cvc: "123",
            name: "Test User"
        )
        ```
        
        ## Debugging
        
        Enable debug logging for detailed information:
        
        ```swift
        let config = VizionGatewayConfig(
            apiKey: "your_test_key",
            environment: .sandbox,
            loggingEnabled: true,
            logLevel: .debug
        )
        
        VizionGateway.initialize(with: config)
        ```
        
        ## Testing Webhooks Locally
        
        Use tools like ngrok to test webhooks during development:
        
        1. Install ngrok and start it:
           ```bash
           ngrok http 3000
           ```
           
        2. Use the provided HTTPS URL in your webhook settings:
           ```swift
           let webhook = WebhookEndpoint(
               url: "https://your-ngrok-url.ngrok.io/webhooks",
               events: [.paymentCreated, .paymentUpdated]
           )
           ```
           
        3. Set up your local server to receive webhook events
        """
    }
    
    private var productionContent: String {
        """
        # Going to Production
        
        Guidelines for transitioning your integration to production.
        
        ## Production Checklist
        
        Before going live, ensure you've completed the following:
        
        - [x] Thoroughly tested all payment scenarios in sandbox
        - [x] Implemented proper error handling
        - [x] Set up webhook handling for asynchronous events
        - [x] Implemented security best practices
        - [x] Completed PCI compliance requirements (if applicable)
        - [x] Configured production API keys securely
        - [x] Updated SDK to the latest version
        
        ## Switching to Production
        
        Update your configuration to use production credentials:
        
        ```swift
        VizionGateway.initialize(
            apiKey: "sk_live_your_live_key",
            environment: .production
        )
        ```
        
        ## Monitoring and Alerts
        
        Set up monitoring for your production integration:
        
        ```swift
        let config = VizionGatewayConfig(
            apiKey: "sk_live_your_live_key",
            environment: .production,
            monitoringEnabled: true,
            alertThreshold: .error // Get alerted on errors only
        )
        
        VizionGateway.initialize(with: config)
        ```
        
        ## Gradual Rollout
        
        Consider a phased approach when going live:
        
        1. Release to internal users only
        2. Release to a small percentage of customers
        3. Gradually increase the percentage
        4. Full rollout after confirming stability
        
        ## Support Access
        
        Ensure your team has access to the Vizion Gateway Dashboard for monitoring and support.
        """
    }
}

// MARK: - Supporting Views and Models

struct DocumentationSection: View {
    let topics: [DocumentationTopic]
    @Binding var selectedTopic: DocumentationTopic?
    @Binding var showingTopic: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(topics) { topic in
                Button {
                    selectedTopic = topic
                    showingTopic = true
                } label: {
                    HStack {
                        Text(topic.title)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(.vertical, 12)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                }
                
                if topic != topics.last {
                    Divider()
                        .padding(.leading)
                }
            }
        }
    }
}

struct DocumentationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let topic: DocumentationTopic
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(.init(topic.content))
                        .padding()
                }
            }
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

enum DocumentationTopicType {
    case gettingStarted
    case integrationGuide
    case apiReference
    case advanced
}

struct DocumentationTopic: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let content: String
    let type: DocumentationTopicType
    
    static func == (lhs: DocumentationTopic, rhs: DocumentationTopic) -> Bool {
        return lhs.id == rhs.id
    }
}

#Preview {
    NavigationView {
        SDKDocumentationView()
    }
} 