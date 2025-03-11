import Foundation
import SwiftData

// MARK: - Payment Models

@Model
final class PaymentTransaction: Identifiable {
    var id: String
    var amount: Decimal
    var currency: Currency
    var status: PaymentStatus
    var type: PaymentType
    var method: PaymentMethod
    var sourceId: String
    var destinationId: String
    var metadata: [String: String]?
    var errorMessage: String?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    
    init(
        amount: Decimal,
        currency: Currency,
        type: PaymentType,
        method: PaymentMethod,
        sourceId: String,
        destinationId: String,
        metadata: [String: String]? = nil
    ) {
        self.id = UUID().uuidString
        self.amount = amount
        self.currency = currency
        self.status = .pending
        self.type = type
        self.method = method
        self.sourceId = sourceId
        self.destinationId = destinationId
        self.metadata = metadata
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum PaymentStatus: String, Codable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case refunded = "refunded"
    case cancelled = "cancelled"
}

enum PaymentType: String, Codable {
    case charge = "charge"
    case refund = "refund"
    case payout = "payout"
    case transfer = "transfer"
}

enum PaymentMethod: String, Codable {
    case card = "card"
    case bankTransfer = "bank_transfer"
    case wallet = "wallet"
    case applePay = "apple_pay"
}

enum Currency: String, Codable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case xcd = "XCD"
    // Add more currencies as needed
}

// MARK: - Payment Provider Protocol

protocol PaymentProvider {
    var type: PaymentProviderType { get }
    
    func processPayment(_ payment: PaymentTransaction) async throws -> PaymentResult
    func refundPayment(_ payment: PaymentTransaction, amount: Decimal?) async throws -> PaymentResult
    func verifyPayment(_ payment: PaymentTransaction) async throws -> PaymentStatus
}

enum PaymentProviderType: String {
    case caribbeanProcessor = "caribbean_processor"
    case applePay = "apple_pay"
}

// MARK: - Payment Result

struct PaymentResult {
    let status: PaymentStatus
    let transactionId: String
    let providerReference: String?
    let errorMessage: String?
    let metadata: [String: String]?
}

// MARK: - Payment Errors

enum PaymentError: LocalizedError {
    case invalidAmount
    case invalidCurrency
    case providerError(String)
    case insufficientFunds
    case cardDeclined
    case paymentCancelled
    case invalidPaymentMethod
    case transactionNotFound
    case refundNotAllowed
    
    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Invalid payment amount"
        case .invalidCurrency:
            return "Invalid or unsupported currency"
        case .providerError(let message):
            return "Payment provider error: \(message)"
        case .insufficientFunds:
            return "Insufficient funds"
        case .cardDeclined:
            return "Card was declined"
        case .paymentCancelled:
            return "Payment was cancelled"
        case .invalidPaymentMethod:
            return "Invalid or unsupported payment method"
        case .transactionNotFound:
            return "Transaction not found"
        case .refundNotAllowed:
            return "Refund not allowed for this transaction"
        }
    }
}

// MARK: - Payment Method Details

struct CardDetails: Codable {
    let last4: String
    let brand: String
    let expiryMonth: Int
    let expiryYear: Int
    let fingerprint: String?
}

struct BankAccountDetails: Codable {
    let accountLast4: String
    let bankName: String
    let routingNumber: String
    let accountType: String
    let accountHolderName: String
}

struct ApplePayDetails: Codable {
    let deviceModel: String
    let transactionIdentifier: String
    let paymentMethod: String
}

// MARK: - Payment Webhook Events

enum PaymentWebhookEvent: String {
    case paymentSucceeded = "payment.succeeded"
    case paymentFailed = "payment.failed"
    case refundProcessed = "refund.processed"
    case refundFailed = "refund.failed"
    case disputeCreated = "dispute.created"
    case disputeResolved = "dispute.resolved"
}

// MARK: - Payment Analytics

struct PaymentAnalytics {
    let transactionId: String
    let amount: Decimal
    let currency: Currency
    let method: PaymentMethod
    let provider: PaymentProviderType
    let processingTime: TimeInterval
    let success: Bool
    let errorType: String?
    let metadata: [String: String]?
} 