import Foundation
import SwiftData

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
    
    // Firebase Dictionary Conversion
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "amount": NSDecimalNumber(decimal: amount).doubleValue,
            "currency": currency,
            "status": status.rawValue,
            "type": type.rawValue,
            "paymentMethod": paymentMethod.rawValue,
            "timestamp": timestamp.timeIntervalSince1970,
            "merchantId": merchantId,
            "merchantName": merchantName,
            "reference": reference,
            "fee": NSDecimalNumber(decimal: fee).doubleValue,
            "netAmount": NSDecimalNumber(decimal: netAmount).doubleValue,
            "environment": environment
        ]
        
        // Optional fields
        if let transactionDescription = transactionDescription { dict["transactionDescription"] = transactionDescription }
        if let metadata = metadata { dict["metadata"] = metadata }
        if let customerId = customerId { dict["customerId"] = customerId }
        if let customerName = customerName { dict["customerName"] = customerName }
        if let externalReference = externalReference { dict["externalReference"] = externalReference }
        if let processorResponse = processorResponse { dict["processorResponse"] = processorResponse }
        if let errorMessage = errorMessage { dict["errorMessage"] = errorMessage }
        if let authorizationCode = authorizationCode { dict["authorizationCode"] = authorizationCode }
        
        return dict
    }
    
    // Initialize from Firebase document
    static func fromDictionary(_ dict: [String: Any], id: String) -> Transaction? {
        guard
            let amountValue = dict["amount"] as? Double,
            let currency = dict["currency"] as? String,
            let statusString = dict["status"] as? String,
            let status = TransactionStatus(rawValue: statusString),
            let typeString = dict["type"] as? String,
            let type = TransactionType(rawValue: typeString),
            let paymentMethodString = dict["paymentMethod"] as? String,
            let paymentMethod = PaymentMethod(rawValue: paymentMethodString),
            let timestampValue = dict["timestamp"] as? TimeInterval,
            let merchantId = dict["merchantId"] as? String,
            let merchantName = dict["merchantName"] as? String,
            let reference = dict["reference"] as? String,
            let feeValue = dict["fee"] as? Double,
            let netAmountValue = dict["netAmount"] as? Double
        else {
            return nil
        }
        
        let amount = Decimal(amountValue)
        let fee = Decimal(feeValue)
        let netAmount = Decimal(netAmountValue)
        let timestamp = Date(timeIntervalSince1970: timestampValue)
        
        let environment = dict["environment"] as? String ?? "sandbox"
        let transactionDescription = dict["transactionDescription"] as? String
        let metadata = dict["metadata"] as? String
        let customerId = dict["customerId"] as? String
        let customerName = dict["customerName"] as? String
        let externalReference = dict["externalReference"] as? String
        let processorResponse = dict["processorResponse"] as? String
        let errorMessage = dict["errorMessage"] as? String
        let authorizationCode = dict["authorizationCode"] as? String
        
        return Transaction(
            id: id,
            amount: amount,
            currency: currency,
            status: status,
            type: type,
            paymentMethod: paymentMethod,
            timestamp: timestamp,
            transactionDescription: transactionDescription,
            metadata: metadata,
            merchantId: merchantId,
            merchantName: merchantName,
            customerId: customerId,
            customerName: customerName,
            reference: reference,
            externalReference: externalReference,
            fee: fee,
            netAmount: netAmount,
            processorResponse: processorResponse,
            errorMessage: errorMessage,
            authorizationCode: authorizationCode,
            environment: environment,
            firebaseId: id
        )
    }
} 