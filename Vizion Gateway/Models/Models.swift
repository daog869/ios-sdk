import SwiftUI
import SwiftData

// MARK: - Time Range

enum TimeRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case year = "This Year"
    
    var id: String { rawValue }
}

// MARK: - Payment Types

struct PaymentData {
    let merchantName: String
    let amount: Decimal
    let reference: String
}

enum PaymentMethod: String, Codable, CaseIterable {
    case debitCard = "Debit Card"
    case bankTransfer = "Bank Transfer"
    case mobileMoney = "Mobile Money"
    case qrCode = "QR Code"
}

enum TransactionStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
    case refunded = "Refunded"
}

enum TransactionType: String, Codable {
    case oneTime = "One-Time"
    case recurring = "Recurring"
    case refund = "Refund"
}

enum KYCStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case submitted = "Submitted"
    case verified = "Verified"
    case rejected = "Rejected"
}

// MARK: - User Model

@Model
final class User {
    var id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String
    var address: String
    var isVerified: Bool
    var kycStatus: KYCStatus
    var createdAt: Date
    var lastLoginAt: Date?
    @Relationship(deleteRule: .cascade) var transactions: [Transaction]
    
    init(
        firstName: String,
        lastName: String,
        email: String,
        phoneNumber: String,
        address: String
    ) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.address = address
        self.isVerified = false
        self.kycStatus = .pending
        self.createdAt = Date()
        self.transactions = []
    }
}

// MARK: - Transaction Model

@Model
final class Transaction {
    var id: UUID
    var amount: Decimal
    var currency: String
    var status: TransactionStatus
    var type: TransactionType
    var paymentMethod: PaymentMethod
    var timestamp: Date
    var transactionDescription: String?
    var merchantName: String
    var customerID: String
    var reference: String?
    
    init(
        amount: Decimal,
        merchantName: String,
        customerID: String,
        type: TransactionType = .oneTime,
        paymentMethod: PaymentMethod,
        description: String? = nil,
        reference: String? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.currency = "XCD"
        self.status = .pending
        self.type = type
        self.paymentMethod = paymentMethod
        self.timestamp = Date()
        self.transactionDescription = description
        self.merchantName = merchantName
        self.customerID = customerID
        self.reference = reference
    }
}

// MARK: - Supporting Views

// Removing duplicate StatusBadge declaration
// struct StatusBadge: View { ... }

// ... existing code ... 