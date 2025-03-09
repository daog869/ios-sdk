import Foundation
import Firebase
import FirebaseFunctions

/// Service for interacting with Firebase Cloud Functions
class FirebaseFunctionService {
    /// Shared instance of the service (singleton)
    static let shared = FirebaseFunctionService()
    
    /// Firebase Functions instance
    private let functions: Functions
    
    /// Private initializer for singleton pattern
    private init() {
        #if DEBUG
        // Use the local emulator in debug mode if emulator is running
        if let emulatorHost = ProcessInfo.processInfo.environment["FUNCTIONS_EMULATOR_HOST"] {
            functions = Functions.functions()
            functions.useEmulator(withHost: emulatorHost, port: 5002)
        } else {
            functions = Functions.functions()
        }
        #else
        functions = Functions.functions()
        #endif
    }
    
    /// Process a payment transaction
    /// - Parameters:
    ///   - amount: The payment amount
    ///   - currency: Currency code (e.g., "USD")
    ///   - merchantId: Merchant identifier
    ///   - apiKey: API key for authentication
    ///   - metadata: Optional metadata for the transaction
    ///   - paymentMethod: Payment method used (default: "card")
    ///   - description: Optional transaction description
    ///   - webhookUrl: Optional URL to receive transaction webhook
    ///   - completion: Callback with result
    func processPayment(
        amount: Double,
        currency: String,
        merchantId: String,
        apiKey: String,
        metadata: [String: Any]? = nil,
        paymentMethod: String = "card",
        description: String? = nil,
        webhookUrl: String? = nil,
        completion: @escaping (Result<PaymentResponse, Error>) -> Void
    ) {
        var data: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "merchantId": merchantId,
            "apiKey": apiKey,
            "paymentMethod": paymentMethod
        ]
        
        if let metadata = metadata { data["metadata"] = metadata }
        if let description = description { data["description"] = description }
        if let webhookUrl = webhookUrl { data["webhookUrl"] = webhookUrl }
        
        functions.httpsCallable("processPayment").call(data) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let resultData = result?.data as? [String: Any] else {
                completion(.failure(NSError(domain: "FirebaseFunctionService", code: 500, 
                                          userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: resultData)
                let response = try JSONDecoder().decode(PaymentResponse.self, from: jsonData)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Generate a report for merchant transactions
    /// - Parameters:
    ///   - merchantId: Merchant identifier
    ///   - apiKey: API key for authentication
    ///   - reportType: Type of report to generate
    ///   - startDate: Start date for report period
    ///   - endDate: End date for report period
    ///   - completion: Callback with result
    func generateReport(
        merchantId: String,
        apiKey: String,
        reportType: String,
        startDate: Date,
        endDate: Date,
        completion: @escaping (Result<ReportResponse, Error>) -> Void
    ) {
        let dateFormatter = ISO8601DateFormatter()
        
        let data: [String: Any] = [
            "merchantId": merchantId,
            "apiKey": apiKey,
            "reportType": reportType,
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate)
        ]
        
        functions.httpsCallable("generateReport").call(data) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let resultData = result?.data as? [String: Any] else {
                completion(.failure(NSError(domain: "FirebaseFunctionService", code: 500,
                                          userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: resultData)
                let response = try JSONDecoder().decode(ReportResponse.self, from: jsonData)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Get transaction statistics for a merchant
    /// - Parameters:
    ///   - merchantId: Merchant identifier
    ///   - apiKey: API key for authentication
    ///   - timeframe: Timeframe for statistics (e.g., "today", "last7days")
    ///   - completion: Callback with result
    func getTransactionStatistics(
        merchantId: String,
        apiKey: String,
        timeframe: String,
        completion: @escaping (Result<StatisticsResponse, Error>) -> Void
    ) {
        let data: [String: Any] = [
            "merchantId": merchantId,
            "apiKey": apiKey,
            "timeframe": timeframe
        ]
        
        functions.httpsCallable("getTransactionStatistics").call(data) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let resultData = result?.data as? [String: Any] else {
                completion(.failure(NSError(domain: "FirebaseFunctionService", code: 500,
                                          userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: resultData)
                let response = try JSONDecoder().decode(StatisticsResponse.self, from: jsonData)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Trigger a test webhook to the specified URL
    /// - Parameters:
    ///   - merchantId: Merchant identifier
    ///   - apiKey: API key for authentication
    ///   - webhookUrl: URL to receive webhook
    ///   - eventType: Type of event to simulate
    ///   - completion: Callback with result
    func triggerWebhook(
        merchantId: String,
        apiKey: String,
        webhookUrl: String,
        eventType: String,
        completion: @escaping (Result<WebhookResponse, Error>) -> Void
    ) {
        let data: [String: Any] = [
            "merchantId": merchantId,
            "apiKey": apiKey,
            "webhookUrl": webhookUrl,
            "eventType": eventType
        ]
        
        functions.httpsCallable("triggerWebhook").call(data) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let resultData = result?.data as? [String: Any] else {
                completion(.failure(NSError(domain: "FirebaseFunctionService", code: 500,
                                          userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: resultData)
                let response = try JSONDecoder().decode(WebhookResponse.self, from: jsonData)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Onboard a new merchant
    /// - Parameters:
    ///   - businessName: Merchant business name
    ///   - email: Contact email
    ///   - contactName: Contact person name
    ///   - address: Business address
    ///   - phone: Optional phone number
    ///   - website: Optional website URL
    ///   - taxId: Optional tax ID
    ///   - webhookUrl: Optional webhook URL
    ///   - paymentMethods: Payment methods to enable
    ///   - currencies: Currencies to support
    ///   - completion: Callback with result
    func onboardMerchant(
        businessName: String,
        email: String,
        contactName: String,
        address: String,
        phone: String? = nil,
        website: String? = nil,
        taxId: String? = nil,
        webhookUrl: String? = nil,
        paymentMethods: [String] = ["card"],
        currencies: [String] = ["USD"],
        completion: @escaping (Result<MerchantResponse, Error>) -> Void
    ) {
        var data: [String: Any] = [
            "businessName": businessName,
            "email": email,
            "contactName": contactName,
            "address": address,
            "paymentMethods": paymentMethods,
            "currencies": currencies
        ]
        
        if let phone = phone { data["phone"] = phone }
        if let website = website { data["website"] = website }
        if let taxId = taxId { data["taxId"] = taxId }
        if let webhookUrl = webhookUrl { data["webhookUrl"] = webhookUrl }
        
        functions.httpsCallable("onboardMerchant").call(data) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let resultData = result?.data as? [String: Any] else {
                completion(.failure(NSError(domain: "FirebaseFunctionService", code: 500,
                                          userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: resultData)
                let response = try JSONDecoder().decode(MerchantResponse.self, from: jsonData)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Response Models

/// Response from processPayment function
struct PaymentResponse: Codable {
    let success: Bool
    let transactionId: String
    let amount: Double
    let currency: String
    let feeAmount: Double
    let netAmount: Double
    let status: String
    let createdAt: String
}

/// Response from generateReport function
struct ReportResponse: Codable {
    let success: Bool
    let reportType: String
    let startDate: String
    let endDate: String
    let transactionCount: Int
    let downloadUrl: String
    let expiresAt: String
}

/// Response from getTransactionStatistics function
struct StatisticsResponse: Codable {
    let success: Bool
    let timeframe: String
    let startDate: String
    let endDate: String
    let totalVolume: Double
    let totalFees: Double
    let totalNet: Double
    let transactionCount: Int
    let averageTransactionSize: Double
    let paymentMethodBreakdown: [String: Int]
    let currencyBreakdown: [String: Int]
}

/// Response from triggerWebhook function
struct WebhookResponse: Codable {
    let success: Bool
    let webhookId: String
    let event: String
    let url: String
    let status: String
    let payload: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case success, webhookId, event, url, status, payload
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        webhookId = try container.decode(String.self, forKey: .webhookId)
        event = try container.decode(String.self, forKey: .event)
        url = try container.decode(String.self, forKey: .url)
        status = try container.decode(String.self, forKey: .status)
        
        // Handle dictionary of mixed types
        if let payloadData = try container.decodeIfPresent(Data.self, forKey: .payload) {
            do {
                payload = try JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any] ?? [:]
            } catch {
                payload = [:]
            }
        } else {
            payload = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(webhookId, forKey: .webhookId)
        try container.encode(event, forKey: .event)
        try container.encode(url, forKey: .url)
        try container.encode(status, forKey: .status)
        
        // Convert payload to JSON data first
        if !payload.isEmpty, let payloadData = try? JSONSerialization.data(withJSONObject: payload) {
            try container.encode(payloadData, forKey: .payload)
        }
    }
}

/// Response from onboardMerchant function
struct MerchantResponse: Codable {
    let success: Bool
    let merchantId: String
    let businessName: String
    let status: String
    let apiKey: ApiKeyInfo
    
    struct ApiKeyInfo: Codable {
        let keyId: String
        let key: String
        let name: String
    }
}

// MARK: - Extensions

extension [String: Any] {
    /// Convert Dictionary to Data for JSON encoding
    func toData() throws -> Data {
        return try JSONSerialization.data(withJSONObject: self)
    }
}

extension Decoder {
    /// Decode a dictionary of mixed types
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return try self.singleValueContainer()
    }
} 