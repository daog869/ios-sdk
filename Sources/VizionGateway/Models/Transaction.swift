import Foundation

/// Represents a payment transaction in the Vizion Gateway system
@available(iOS 17.0, macOS 14.0, *)
public struct Transaction: Codable, Identifiable {
    /// Unique identifier for the transaction
    public let id: String
    
    /// Amount of the transaction
    public let amount: Decimal
    
    /// Currency code (e.g. XCD)
    public let currency: String
    
    /// Status of the transaction
    public let status: TransactionStatus
    
    /// Type of the transaction
    public let type: TransactionType
    
    /// ID of the source account/wallet
    public let sourceId: String
    
    /// ID of the destination account/wallet
    public let destinationId: String
    
    /// Associated order ID if applicable
    public let orderId: String?
    
    /// Merchant ID associated with the transaction
    public let merchantId: String
    
    /// Timestamp when the transaction was created
    public let createdAt: Date
    
    /// Timestamp when the transaction was last updated
    public let updatedAt: Date
    
    /// Optional error message if the transaction failed
    public let errorMessage: String?
    
    /// Optional metadata associated with the transaction
    public let metadata: [String: String]?
}

/// Status of a transaction
@available(iOS 17.0, macOS 14.0, *)
public enum TransactionStatus: String, Codable {
    /// Transaction is pending processing
    case pending
    
    /// Transaction has been completed successfully
    case completed
    
    /// Transaction has failed
    case failed
    
    /// Transaction has been refunded
    case refunded
    
    /// Transaction has been voided
    case voided
    
    /// Transaction is under review
    case underReview
}

/// Type of transaction
@available(iOS 17.0, macOS 14.0, *)
public enum TransactionType: String, Codable {
    /// Direct card payment
    case cardPayment
    
    /// Apple Pay payment
    case applePay
    
    /// Wallet payment
    case wallet
    
    /// Refund
    case refund
    
    /// Subscription payment
    case subscription
    
    /// Payout to merchant
    case payout
} 