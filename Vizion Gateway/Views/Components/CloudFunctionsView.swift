import SwiftUI

struct CloudFunctionsView: View {
    @State private var processingPayment = false
    @State private var paymentAmount = ""
    @State private var merchantId = ""
    @State private var resultMessage = ""
    @State private var paymentStatus: PaymentStatus?
    
    var body: some View {
        Form {
            Section("Payment Processing") {
                TextField("Amount", text: $paymentAmount)
                    .keyboardType(.decimalPad)
                
                TextField("Merchant ID", text: $merchantId)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button(action: processPayment) {
                    if processingPayment {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Process Payment")
                    }
                }
                .disabled(processingPayment || paymentAmount.isEmpty || merchantId.isEmpty)
                .frame(maxWidth: .infinity)
            }
            
            if let status = paymentStatus {
                Section("Result") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Status:")
                                .fontWeight(.medium)
                            
                            Text(status.status)
                                .foregroundStyle(
                                    status.status == "succeeded" ? Color.green :
                                    status.status == "failed" ? Color.red : Color.orange
                                )
                        }
                        
                        HStack {
                            Text("Transaction ID:")
                                .fontWeight(.medium)
                            
                            Text(status.transactionId)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Amount:")
                                .fontWeight(.medium)
                            
                            Text("$\(String(format: "%.2f", status.amount))")
                        }
                        
                        if let message = status.message {
                            HStack {
                                Text("Message:")
                                    .fontWeight(.medium)
                                
                                Text(message)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let timestamp = status.timestamp {
                            HStack {
                                Text("Timestamp:")
                                    .fontWeight(.medium)
                                
                                Text(timestamp.formatted(date: .abbreviated, time: .standard))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            Section("Other Cloud Functions") {
                Button("Generate Report") {
                    generateReport()
                }
                
                Button("Calculate Transaction Statistics") {
                    calculateStatistics()
                }
                
                Button("Test Webhook Delivery") {
                    testWebhook()
                }
            }
        }
        .navigationTitle("Cloud Functions")
        .alert("Function Result", isPresented: .init(get: { !resultMessage.isEmpty }, set: { if !$0 { resultMessage = "" }})) {
            Button("OK") {
                resultMessage = ""
            }
        } message: {
            Text(resultMessage)
        }
    }
    
    // MARK: - Cloud Functions Examples
    
    private func processPayment() {
        guard let amount = Double(paymentAmount) else { return }
        
        processingPayment = true
        
        Task {
            do {
                // Prepare payment data
                let paymentData: [String: Any] = [
                    "amount": amount,
                    "merchantId": merchantId,
                    "currency": "USD",
                    "environment": UserDefaults.standard.string(forKey: "environment") ?? "sandbox"
                ]
                
                // Call the Cloud Function
                let result: PaymentStatus = try await FirebaseManager.shared.callFunction(
                    name: "processPayment", 
                    data: paymentData
                )
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    paymentStatus = result
                    processingPayment = false
                }
            } catch {
                // Handle errors
                DispatchQueue.main.async {
                    resultMessage = "Payment processing failed: \(error.localizedDescription)"
                    processingPayment = false
                }
            }
        }
    }
    
    private func generateReport() {
        Task {
            do {
                // Example of calling a function that returns a URL to a generated report
                let reportData: [String: Any] = [
                    "reportType": "transactions",
                    "startDate": Date().addingTimeInterval(-86400 * 30).timeIntervalSince1970,
                    "endDate": Date().timeIntervalSince1970,
                    "format": "pdf"
                ]
                
                // Call the Cloud Function
                let result: ReportResult = try await FirebaseManager.shared.callFunction(
                    name: "generateReport", 
                    data: reportData
                )
                
                // Update UI
                DispatchQueue.main.async {
                    resultMessage = "Report generated! Download URL: \(result.downloadUrl)"
                }
            } catch {
                DispatchQueue.main.async {
                    resultMessage = "Report generation failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func calculateStatistics() {
        Task {
            do {
                // Example of getting statistics on transactions
                let requestData: [String: Any] = [
                    "timeframe": "last30days",
                    "merchantId": merchantId.isEmpty ? "all" : merchantId
                ]
                
                // Call the Cloud Function
                let result: StatisticsResult = try await FirebaseManager.shared.callFunction(
                    name: "getTransactionStatistics", 
                    data: requestData
                )
                
                // Update UI
                DispatchQueue.main.async {
                    resultMessage = """
                    Total Transactions: \(result.totalCount)
                    Total Volume: $\(String(format: "%.2f", result.totalVolume))
                    Average Transaction: $\(String(format: "%.2f", result.averageAmount))
                    Success Rate: \(String(format: "%.1f%%", result.successRate * 100))
                    """
                }
            } catch {
                DispatchQueue.main.async {
                    resultMessage = "Statistics calculation failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func testWebhook() {
        Task {
            do {
                // Example of triggering a test webhook
                let webhookData: [String: Any] = [
                    "event": "payment.created",
                    "testMode": true,
                    "destination": "https://example.com/webhooks"
                ]
                
                // Call the Cloud Function
                let result: WebhookResult = try await FirebaseManager.shared.callFunction(
                    name: "triggerWebhook", 
                    data: webhookData
                )
                
                // Update UI
                DispatchQueue.main.async {
                    resultMessage = """
                    Webhook Delivery: \(result.success ? "Succeeded" : "Failed")
                    Status Code: \(result.statusCode)
                    Message: \(result.message)
                    """
                }
            } catch {
                DispatchQueue.main.async {
                    resultMessage = "Webhook test failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct PaymentStatus: Codable {
    let status: String
    let transactionId: String
    let amount: Double
    let message: String?
    let timestamp: Date?
    
    enum CodingKeys: String, CodingKey {
        case status
        case transactionId
        case amount
        case message
        case timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        transactionId = try container.decode(String.self, forKey: .transactionId)
        amount = try container.decode(Double.self, forKey: .amount)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        
        // Decode timestamp from seconds since epoch
        if let timestampSeconds = try container.decodeIfPresent(Double.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: timestampSeconds)
        } else {
            timestamp = nil
        }
    }
}

struct ReportResult: Codable {
    let success: Bool
    let downloadUrl: String
    let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case success
        case downloadUrl
        case expiresAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        downloadUrl = try container.decode(String.self, forKey: .downloadUrl)
        
        // Decode expiresAt from seconds since epoch
        if let expiresAtSeconds = try container.decodeIfPresent(Double.self, forKey: .expiresAt) {
            expiresAt = Date(timeIntervalSince1970: expiresAtSeconds)
        } else {
            expiresAt = nil
        }
    }
}

struct StatisticsResult: Codable {
    let totalCount: Int
    let totalVolume: Double
    let averageAmount: Double
    let successRate: Double
}

struct WebhookResult: Codable {
    let success: Bool
    let statusCode: Int
    let message: String
}

#Preview {
    NavigationView {
        CloudFunctionsView()
    }
} 