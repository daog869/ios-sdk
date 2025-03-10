import Foundation
import SwiftData

@Model
final class WalletTransaction: Identifiable {
    var id: String
    var type: WalletTransactionType
    var status: WalletTransactionStatus
    var amount: Double
    var currency: Currency
    var fee: Double
    var platformFee: Double
    var reserveAmount: Double
    var netAmount: Double
    var reference: String?
    var transactionDescription: String?
    var metadata: [String: String]?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var failedReason: String?
    
    // Source and destination info
    var sourceType: EntityType
    var sourceId: String
    var destinationType: EntityType
    var destinationId: String
    
    // Exchange rate info for multi-currency transactions
    var exchangeRate: Double?
    var originalCurrency: Currency?
    var originalAmount: Double?
    
    // External reference IDs
    var externalId: String?
    var gatewayTransactionId: String?
    
    // Relationships - will be handled by SwiftData
    var wallet: Wallet?
    
    init(id: String = UUID().uuidString,
         type: WalletTransactionType,
         status: WalletTransactionStatus = .pending,
         amount: Double,
         currency: Currency,
         fee: Double = 0.0,
         platformFee: Double = 0.0,
         reserveAmount: Double = 0.0,
         sourceType: EntityType,
         sourceId: String,
         destinationType: EntityType,
         destinationId: String,
         reference: String? = nil,
         description: String? = nil,
         metadata: [String: String]? = nil) {
        self.id = id
        self.type = type
        self.status = status
        self.amount = amount
        self.currency = currency
        self.fee = fee
        self.platformFee = platformFee
        self.reserveAmount = reserveAmount
        self.netAmount = amount - fee - platformFee - reserveAmount
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.destinationType = destinationType
        self.destinationId = destinationId
        self.reference = reference
        self.transactionDescription = description
        self.metadata = metadata
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Mark transaction as completed
    func markCompleted() {
        self.status = WalletTransactionStatus.completed
        self.completedAt = Date()
        self.updatedAt = Date()
    }
    
    // Mark transaction as failed
    func markFailed(reason: String) {
        self.status = WalletTransactionStatus.failed
        self.failedReason = reason
        self.updatedAt = Date()
    }
    
    // Calculate amounts (fees, reserves) based on configured rules
    func calculateAmounts(walletReservePercentage: Double, feePercentage: Double, platformFeePercentage: Double) {
        self.fee = amount * feePercentage
        self.platformFee = amount * platformFeePercentage
        self.reserveAmount = amount * walletReservePercentage
        self.netAmount = amount - fee - platformFee - reserveAmount
        self.updatedAt = Date()
    }
}

// Supporting Types
enum WalletTransactionType: String, Codable {
    case deposit
    case withdrawal
    case payment
    case refund
    case chargeback
    case fee
    case transfer
    case settlement
    case reserveRelease
}

enum WalletTransactionStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed
    case reversed
    case disputed
}

enum EntityType: String, Codable {
    case user
    case merchant
    case platform
    case bank
    case card
    case external
}

@Model
final class WithdrawalRequest: Identifiable {
    var id: String
    var userId: String
    var amount: Double
    var currency: Currency
    var status: WithdrawalStatus
    var destinationType: WithdrawalDestination
    var destinationDetails: [String: String]
    var requestedAt: Date
    var processedAt: Date?
    var rejectionReason: String?
    var transactionId: String?
    
    var wallet: Wallet?
    
    init(id: String = UUID().uuidString,
         userId: String,
         amount: Double,
         currency: Currency,
         destinationType: WithdrawalDestination,
         destinationDetails: [String: String]) {
        self.id = id
        self.userId = userId
        self.amount = amount
        self.currency = currency
        self.status = .pending
        self.destinationType = destinationType
        self.destinationDetails = destinationDetails
        self.requestedAt = Date()
    }
    
    func approve() {
        self.status = .approved
        self.processedAt = Date()
    }
    
    func reject(reason: String) {
        self.status = .rejected
        self.rejectionReason = reason
        self.processedAt = Date()
    }
    
    func complete(transactionId: String) {
        self.status = .completed
        self.transactionId = transactionId
        self.processedAt = Date()
    }
}

enum WithdrawalStatus: String, Codable {
    case pending
    case approved
    case rejected
    case processing
    case completed
    case failed
}

enum WithdrawalDestination: String, Codable {
    case bankAccount
    case card
    case wallet
} 