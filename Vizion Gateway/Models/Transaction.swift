import Foundation
import SwiftData
import FirebaseFirestore

enum TransactionStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
    case refunded = "Refunded"
    case disputed = "Disputed"
    case cancelled = "Cancelled"
}

enum TransactionType: String, Codable, CaseIterable {
    case payment = "Payment"
    case refund = "Refund"
    case payout = "Payout"
    case fee = "Fee"
    case chargeback = "Chargeback"
    case adjustment = "Adjustment"
}

enum PaymentMethod: String, Codable, CaseIterable {
    case debitCard = "Debit Card"
    case creditCard = "Credit Card"
    case bankTransfer = "Bank Transfer"
    case mobileMoney = "Mobile Money"
    case qrCode = "QR Code"
    case wallet = "Digital Wallet"
}

@Model
final class Transaction {
    var id: String
    var amount: Decimal
    var currency: String
    var status: TransactionStatus
    var type: TransactionType
    var paymentMethod: PaymentMethod
    var timestamp: Date
    var transactionDescription: String?
    var metadata: String?  // JSON string for additional metadata
    
    // Relationships
    var merchantId: String
    var merchantName: String
    var customerId: String?
    var customerName: String?
    
    // Reference information
    var reference: String
    var externalReference: String?
    
    // Fee information
    var fee: Decimal
    var netAmount: Decimal
    
    // Processing information
    var processorResponse: String?
    var errorMessage: String?
    var authorizationCode: String?
    
    // Environment information
    var environment: String  // "sandbox" or "production"
    
    // Firebase identifiers
    var firebaseId: String?
    
    // Default initializer
    init(
        id: String = UUID().uuidString,
        amount: Decimal,
        currency: String = "XCD",
        status: TransactionStatus = .pending,
        type: TransactionType,
        paymentMethod: PaymentMethod,
        timestamp: Date = Date(),
        transactionDescription: String? = nil,
        metadata: String? = nil,
        merchantId: String,
        merchantName: String,
        customerId: String? = nil,
        customerName: String? = nil,
        reference: String,
        externalReference: String? = nil,
        fee: Decimal = 0,
        netAmount: Decimal? = nil,
        processorResponse: String? = nil,
        errorMessage: String? = nil,
        authorizationCode: String? = nil,
        environment: String = "sandbox",
        firebaseId: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.status = status
        self.type = type
        self.paymentMethod = paymentMethod
        self.timestamp = timestamp
        self.transactionDescription = transactionDescription
        self.metadata = metadata
        self.merchantId = merchantId
        self.merchantName = merchantName
        self.customerId = customerId
        self.customerName = customerName
        self.reference = reference
        self.externalReference = externalReference
        self.fee = fee
        self.netAmount = netAmount ?? (amount - fee)
        self.processorResponse = processorResponse
        self.errorMessage = errorMessage
        self.authorizationCode = authorizationCode
        self.environment = environment
        self.firebaseId = firebaseId
    }
    
    // The toDictionary and fromDictionary methods are already implemented in FirebaseSerializable.swift
    // via the extension Transaction: FirebaseSerializable

    // MARK: - Preview Helpers
    static func previewTransaction(
        merchantId: String = "MERCH123",
        merchantName: String = "Test Merchant",
        customerId: String? = nil,
        customerName: String? = nil,
        reference: String = "TXN-123456",
        fee: Decimal = 1.00,
        authorizationCode: String? = nil
    ) -> Transaction {
        Transaction(
            id: "TX\(Int.random(in: 100000...999999))",
            amount: 99.99,
            currency: "XCD",
            status: .completed,
            type: .payment,
            paymentMethod: .creditCard,
            timestamp: Date(),
            transactionDescription: "Test transaction",
            merchantId: merchantId,
            merchantName: merchantName,
            customerId: customerId,
            customerName: customerName,
            reference: reference,
            fee: fee,
            authorizationCode: authorizationCode
        )
    }
} 