import Foundation

/// Manages all payment-related operations in the Vizion Gateway SDK
@available(iOS 17.0, macOS 14.0, *)
public final class PaymentManager {
    
    // MARK: - Properties
    
    private let networkManager: NetworkManager
    private let logger: Logger
    
    // MARK: - Initialization
    
    public init() {
        self.networkManager = NetworkManager()
        self.logger = Logger.shared
    }
    
    // MARK: - Public Methods
    
    /// Process a direct card payment
    /// - Parameters:
    ///   - amount: The payment amount
    ///   - currency: The currency code (e.g. XCD)
    ///   - sourceId: The customer's ID
    ///   - destinationId: The merchant's ID
    ///   - orderId: The unique order identifier
    ///   - metadata: Optional additional data
    /// - Returns: The transaction details
    public func processCardPayment(
        amount: Decimal,
        currency: String,
        sourceId: String,
        destinationId: String,
        orderId: String? = nil,
        metadata: [String: String]? = nil
    ) async throws -> Transaction {
        logger.info("Processing card payment: amount=\(amount) currency=\(currency)")
        
        guard VizionGateway.shared.isConfigured else {
            logger.error("SDK not configured")
            throw NetworkError.unauthorized
        }
        
        let request = PaymentRequest(
            amount: amount,
            currency: currency,
            sourceId: sourceId,
            destinationId: destinationId,
            orderId: orderId,
            metadata: metadata
        )
        
        do {
            let transaction: Transaction = try await networkManager.request(
                endpoint: "payments",
                method: "POST",
                body: request
            )
            
            logger.info("Payment processed successfully: transactionId=\(transaction.id)")
            return transaction
        } catch {
            logger.error("Payment processing failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Process a refund for a transaction
    /// - Parameters:
    ///   - transactionId: The ID of the transaction to refund
    ///   - amount: Optional amount to refund (if nil, full amount is refunded)
    ///   - reason: The reason for the refund
    /// - Returns: The refund transaction details
    public func processRefund(
        transactionId: String,
        amount: Decimal? = nil,
        reason: String? = nil
    ) async throws -> Refund {
        logger.info("Processing refund for transaction: \(transactionId)")
        
        guard VizionGateway.shared.isConfigured else {
            logger.error("SDK not configured")
            throw NetworkError.unauthorized
        }
        
        let request = RefundRequest(
            transactionId: transactionId,
            amount: amount,
            reason: reason
        )
        
        do {
            let refund: Refund = try await networkManager.request(
                endpoint: "refunds",
                method: "POST",
                body: request
            )
            
            logger.info("Refund processed successfully: refundId=\(refund.id)")
            return refund
        } catch {
            logger.error("Refund processing failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Retrieve transaction history
    /// - Parameters:
    ///   - startDate: Optional start date for filtering
    ///   - endDate: Optional end date for filtering
    ///   - limit: Maximum number of transactions to return (default: 50)
    /// - Returns: Array of transactions
    public func getTransactionHistory(
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int = 50
    ) async throws -> [Transaction] {
        logger.info("Retrieving transaction history")
        
        guard VizionGateway.shared.isConfigured else {
            logger.error("SDK not configured")
            throw NetworkError.unauthorized
        }
        
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: ISO8601DateFormatter().string(from: startDate)))
        }
        
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: ISO8601DateFormatter().string(from: endDate)))
        }
        
        var endpoint = "transactions"
        if !queryItems.isEmpty {
            let queryString = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            endpoint += "?\(queryString)"
        }
        
        do {
            let transactions: [Transaction] = try await networkManager.request(
                endpoint: endpoint,
                method: "GET"
            )
            
            logger.info("Retrieved \(transactions.count) transactions")
            return transactions
        } catch {
            logger.error("Failed to retrieve transaction history: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Supporting Types

@available(iOS 17.0, macOS 14.0, *)
extension PaymentManager {
    
    struct PaymentRequest: Encodable {
        let amount: Decimal
        let currency: String
        let sourceId: String
        let destinationId: String
        let orderId: String?
        let metadata: [String: String]?
    }
    
    struct RefundRequest: Encodable {
        let transactionId: String
        let amount: Decimal?
        let reason: String?
    }
}

@available(iOS 17.0, macOS 14.0, *)
public enum PaymentError: Error {
    case sdkNotConfigured
    case invalidURL
    case encodingError
    case decodingError
    case networkError(Error)
    case serverError(Int)
    case invalidResponse
    case noData
    
    public var localizedDescription: String {
        switch self {
        case .sdkNotConfigured:
            return "SDK not configured. Call VizionGateway.configure() first."
        case .invalidURL:
            return "Invalid URL for API request"
        case .encodingError:
            return "Failed to encode request data"
        case .decodingError:
            return "Failed to decode response data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error with status code: \(code)"
        case .invalidResponse:
            return "Invalid response from server"
        case .noData:
            return "No data received from server"
        }
    }
} 