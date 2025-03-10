import Foundation
import SwiftData
import FirebaseFirestore

// Protocol to define required methods for Firebase serialization
protocol FirebaseSerializable {
    // Convert model to dictionary for Firestore
    func toDictionary() -> [String: Any]
    
    // Create model from Firestore dictionary
    static func fromDictionary(_ dictionary: [String: Any], id: String) -> Self?
}

// MARK: - User Extensions

extension User: FirebaseSerializable {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "isActive": isActive,
            "createdAt": Timestamp(date: createdAt),
            "role": role.rawValue
        ]
        
        // Add optional fields if they exist
        if let phone = phone {
            dict["phone"] = phone
        }
        
        if let lastLogin = lastLogin {
            dict["lastLogin"] = Timestamp(date: lastLogin)
        }
        
        if let firebaseId = firebaseId {
            dict["firebaseId"] = firebaseId
        }
        
        return dict
    }
    
    static func fromDictionary(_ dictionary: [String: Any], id: String) -> User? {
        guard
            let firstName = dictionary["firstName"] as? String,
            let lastName = dictionary["lastName"] as? String,
            let email = dictionary["email"] as? String,
            let isActive = dictionary["isActive"] as? Bool,
            let roleString = dictionary["role"] as? String,
            let role = UserRole(rawValue: roleString),
            let createdTimestamp = dictionary["createdAt"] as? Timestamp
        else {
            return nil
        }
        
        let phone = dictionary["phone"] as? String
        let firebaseId = dictionary["firebaseId"] as? String
        
        let lastLoginTimestamp = dictionary["lastLogin"] as? Timestamp
        let lastLogin = lastLoginTimestamp?.dateValue()
        
        let user = User(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            role: role,
            isActive: isActive,
            createdAt: createdTimestamp.dateValue(),
            lastLogin: lastLogin,
            firebaseId: firebaseId
        )
        
        return user
    }
}

// MARK: - Transaction Extensions

extension Transaction: FirebaseSerializable {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "amount": NSDecimalNumber(decimal: amount).doubleValue,
            "currency": currency,
            "status": status.rawValue,
            "type": type.rawValue,
            "paymentMethod": paymentMethod.rawValue,
            "timestamp": Timestamp(date: timestamp),
            "merchantId": merchantId,
            "merchantName": merchantName,
            "fee": NSDecimalNumber(decimal: fee).doubleValue,
            "netAmount": NSDecimalNumber(decimal: netAmount).doubleValue,
            "reference": reference
        ]
        
        // Add optional fields if they exist
        if let customerId = customerId {
            dict["customerId"] = customerId
        }
        
        if let customerName = customerName {
            dict["customerName"] = customerName
        }
        
        if let transactionDescription = transactionDescription {
            dict["transactionDescription"] = transactionDescription
        }
        
        if let metadata = metadata {
            dict["metadata"] = metadata
        }
        
        if let externalReference = externalReference {
            dict["externalReference"] = externalReference
        }
        
        if let processorResponse = processorResponse {
            dict["processorResponse"] = processorResponse
        }
        
        if let errorMessage = errorMessage {
            dict["errorMessage"] = errorMessage
        }
        
        return dict
    }
    
    static func fromDictionary(_ dictionary: [String: Any], id: String) -> Transaction? {
        guard
            let amountValue = dictionary["amount"] as? NSNumber,
            let currency = dictionary["currency"] as? String,
            let statusString = dictionary["status"] as? String,
            let status = TransactionStatus(rawValue: statusString),
            let typeString = dictionary["type"] as? String,
            let type = TransactionType(rawValue: typeString),
            let paymentMethodString = dictionary["paymentMethod"] as? String,
            let paymentMethod = PaymentMethod(rawValue: paymentMethodString),
            let timestamp = dictionary["timestamp"] as? Timestamp,
            let merchantId = dictionary["merchantId"] as? String,
            let merchantName = dictionary["merchantName"] as? String,
            let feeValue = dictionary["fee"] as? NSNumber,
            let netAmountValue = dictionary["netAmount"] as? NSNumber,
            let reference = dictionary["reference"] as? String
        else {
            return nil
        }
        
        let amount = Decimal(string: amountValue.stringValue) ?? Decimal(0)
        let fee = Decimal(string: feeValue.stringValue) ?? Decimal(0)
        let netAmount = Decimal(string: netAmountValue.stringValue) ?? Decimal(0)
        
        // Optional fields
        let customerId = dictionary["customerId"] as? String
        let customerName = dictionary["customerName"] as? String
        let transactionDescription = dictionary["transactionDescription"] as? String
        let metadata = dictionary["metadata"] as? String
        let externalReference = dictionary["externalReference"] as? String
        let processorResponse = dictionary["processorResponse"] as? String
        let errorMessage = dictionary["errorMessage"] as? String
        
        let transaction = Transaction(
            id: id,
            amount: amount,
            currency: currency,
            status: status,
            type: type,
            paymentMethod: paymentMethod,
            timestamp: timestamp.dateValue(),
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
            errorMessage: errorMessage
        )
        
        return transaction
    }
} 