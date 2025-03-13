import Foundation
import PassKit
import UIKit
import CryptoKit
import SwiftUI

// MARK: - VizionGateway SDK Main Class

public final class VizionGateway {
    // MARK: - Singleton
    
    public static let shared = VizionGateway()
    
    // MARK: - Properties
    
    private var apiKey: String?
    private var environment: Environment = .sandbox
    private var merchantId: String?
    
    private let baseURLs: [Environment: URL] = [
        .sandbox: URL(string: "https://api.sandbox.viziongateway.com/v1")!,
        .production: URL(string: "https://api.viziongateway.com/v1")!
    ]
    
    // MARK: - Configuration
    
    /// Configure the SDK with your API key and environment
    /// - Parameters:
    ///   - apiKey: Your Vizion Gateway API key
    ///   - environment: The environment to use (sandbox or production)
    ///   - merchantId: Your merchant ID
    public func configure(apiKey: String, environment: Environment = .sandbox, merchantId: String? = nil) {
        self.apiKey = apiKey
        self.environment = environment
        self.merchantId = merchantId
        
        CacheManager.shared.configure()
        Logger.log("VizionGateway SDK configured for \(environment) environment")
    }
    
    // MARK: - API Access
    
    /// Get the current base URL for API calls
    var baseURL: URL {
        return baseURLs[environment]!
    }
    
    /// Check if the SDK is properly configured
    var isConfigured: Bool {
        return apiKey != nil
    }
    
    /// Get the Bearer authentication header for API requests
    var authorizationHeader: String? {
        guard let apiKey = apiKey else { return nil }
        return "Bearer \(apiKey)"
    }
    
    // MARK: - Availability Handling for iOS 17+
    
    /// Helper method to handle different API behaviors based on iOS version
    @available(iOS 15.0, *)
    public func performVersionSpecificOperation(completion: @escaping (Result<String, Error>) -> Void) {
        if #available(iOS 17.0, *) {
            // iOS 17+ specific implementation
            DispatchQueue.main.async {
                completion(.success("Using iOS 17+ API"))
            }
        } else {
            // iOS 15 and 16 implementation
            DispatchQueue.main.async {
                completion(.success("Using iOS 15-16 API"))
            }
        }
    }
    
    // MARK: - Payment Processing
    
    /// Process a payment using the configured API key
    public func processPayment(
        amount: Decimal,
        currency: String,
        payment_method: [String: Any],
        customerInfo: [String: String]? = nil,
        metadata: [String: String]? = nil,
        completion: @escaping (Result<Transaction, PaymentError>) -> Void
    ) {
        guard isConfigured else {
            completion(.failure(.configurationError))
            return
        }
        
        // Build payment request
        var body: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "payment_method": payment_method
        ]
        
        if let customerInfo = customerInfo {
            body["customer"] = customerInfo
        }
        
        if let metadata = metadata {
            body["metadata"] = metadata
        }
        
        if let merchantId = merchantId {
            body["merchant_id"] = merchantId
        }
        
        // Make API request
        let url = baseURL.appendingPathComponent("payments")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authHeader = authorizationHeader {
            request.addValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.invalidRequestData))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.emptyResponse))
                return
            }
            
            do {
                let transaction = try JSONDecoder().decode(Transaction.self, from: data)
                completion(.success(transaction))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }
}

// MARK: - Environment Enum

public enum Environment: String {
    case sandbox
    case production
}

// MARK: - Payment Error

public enum PaymentError: Error {
    case configurationError
    case invalidRequestData
    case networkError(Error)
    case emptyResponse
    case decodingError(Error)
    case serverError(String)
    case invalidPaymentMethod
    
    var localizedDescription: String {
        switch self {
        case .configurationError:
            return "SDK is not properly configured. Please call configure() with your API key."
        case .invalidRequestData:
            return "Invalid request data."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .emptyResponse:
            return "Empty response from server."
        case .decodingError(let error):
            return "Error decoding response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidPaymentMethod:
            return "Invalid payment method."
        }
    }
}

// MARK: - Transaction Model

public struct Transaction: Codable {
    public let id: String
    public let amount: Decimal
    public let currency: String
    public let status: TransactionStatus
    public let createdAt: Date
    public let paymentMethod: PaymentMethod
    
    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case currency
        case status
        case createdAt = "created_at"
        case paymentMethod = "payment_method"
    }
}

public enum TransactionStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed
    case refunded
    case canceled
}

public struct PaymentMethod: Codable {
    public let type: String
    public let last4: String?
} 