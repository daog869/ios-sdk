import Foundation

/// Represents a refund transaction in the Vizion Gateway system
@available(iOS 17.0, macOS 14.0, *)
public struct Refund: Codable, Identifiable {
    /// Unique identifier for the refund
    public let id: String
    
    /// ID of the original transaction being refunded
    public let transactionId: String
    
    /// Amount being refunded
    public let amount: Decimal
    
    /// Currency code (e.g. XCD)
    public let currency: String
    
    /// Status of the refund
    public let status: RefundStatus
    
    /// Reason for the refund
    public let reason: String
    
    /// Merchant ID associated with the refund
    public let merchantId: String
    
    /// Timestamp when the refund was created
    public let createdAt: Date
    
    /// Timestamp when the refund was last updated
    public let updatedAt: Date
    
    /// Optional error message if the refund failed
    public let errorMessage: String?
    
    /// Optional metadata associated with the refund
    public let metadata: [String: String]?
}

/// Status of a refund
@available(iOS 17.0, macOS 14.0, *)
public enum RefundStatus: String, Codable {
    /// Refund is pending processing
    case pending
    
    /// Refund has been completed successfully
    case completed
    
    /// Refund has failed
    case failed
    
    /// Refund is under review
    case underReview
} 