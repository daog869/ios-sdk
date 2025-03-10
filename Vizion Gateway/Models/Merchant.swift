import Foundation
import SwiftData

@Model
final class Merchant: Identifiable {
    var id: String
    var name: String
    var businessType: String
    var merchantType: MerchantType
    var contactEmail: String
    var contactPhone: String?
    var address: String?
    var island: Island
    var taxId: String?
    var bankAccount: BankAccount?
    var status: MerchantStatus
    var kycStatus: KYCStatus
    var createdAt: Date
    var updatedAt: Date
    
    // Additional business information
    var websiteUrl: String?
    var logoUrl: String?
    var businessDescription: String?
    
    // Settings and configuration
    var settlementPeriod: Int // In days
    var transactionFeePercentage: Decimal
    var flatFeeCents: Int
    
    // Firebase identifiers
    var firebaseId: String?
    
    // Relationships (transient, not stored in SwiftData)
    @Transient var apiKeys: [APIKey]?
    @Transient var transactions: [Transaction]?
    @Transient var terminals: [POSTerminal]?
    
    // Default initializer
    init(
        id: String = UUID().uuidString,
        name: String,
        businessType: String,
        merchantType: MerchantType = .api,
        contactEmail: String,
        contactPhone: String? = nil,
        address: String? = nil,
        island: Island,
        taxId: String? = nil,
        bankAccount: BankAccount? = nil,
        status: MerchantStatus = .pending,
        kycStatus: KYCStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        websiteUrl: String? = nil,
        logoUrl: String? = nil,
        businessDescription: String? = nil,
        settlementPeriod: Int = 1,
        transactionFeePercentage: Decimal = 0.029, // 2.9% default
        flatFeeCents: Int = 30, // $0.30 default
        firebaseId: String? = nil,
        apiKeys: [APIKey]? = nil,
        transactions: [Transaction]? = nil,
        terminals: [POSTerminal]? = nil
    ) {
        self.id = id
        self.name = name
        self.businessType = businessType
        self.merchantType = merchantType
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.address = address
        self.island = island
        self.taxId = taxId
        self.bankAccount = bankAccount
        self.status = status
        self.kycStatus = kycStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.websiteUrl = websiteUrl
        self.logoUrl = logoUrl
        self.businessDescription = businessDescription
        self.settlementPeriod = settlementPeriod
        self.transactionFeePercentage = transactionFeePercentage
        self.flatFeeCents = flatFeeCents
        self.firebaseId = firebaseId
        self.apiKeys = apiKeys
        self.transactions = transactions
        self.terminals = terminals
    }
    
    // Firebase Dictionary Conversion
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "businessType": businessType,
            "merchantType": merchantType.rawValue,
            "contactEmail": contactEmail,
            "island": island.rawValue,
            "status": status.rawValue,
            "kycStatus": kycStatus.rawValue,
            "createdAt": createdAt.timeIntervalSince1970,
            "updatedAt": updatedAt.timeIntervalSince1970,
            "settlementPeriod": settlementPeriod,
            "transactionFeePercentage": NSDecimalNumber(decimal: transactionFeePercentage).doubleValue,
            "flatFeeCents": flatFeeCents
        ]
        
        // Optional fields
        if let contactPhone = contactPhone { dict["contactPhone"] = contactPhone }
        if let address = address { dict["address"] = address }
        if let taxId = taxId { dict["taxId"] = taxId }
        if let websiteUrl = websiteUrl { dict["websiteUrl"] = websiteUrl }
        if let logoUrl = logoUrl { dict["logoUrl"] = logoUrl }
        if let businessDescription = businessDescription { dict["businessDescription"] = businessDescription }
        if let bankAccount = bankAccount { dict["bankAccount"] = bankAccount.toDictionary() }
        
        return dict
    }
    
    // Initialize from Firebase document
    static func fromDictionary(_ dict: [String: Any], id: String) -> Merchant? {
        guard
            let name = dict["name"] as? String,
            let businessType = dict["businessType"] as? String,
            let merchantTypeString = dict["merchantType"] as? String,
            let merchantType = MerchantType(rawValue: merchantTypeString),
            let contactEmail = dict["contactEmail"] as? String,
            let islandString = dict["island"] as? String,
            let island = Island(rawValue: islandString),
            let statusString = dict["status"] as? String,
            let status = MerchantStatus(rawValue: statusString),
            let kycStatusString = dict["kycStatus"] as? String,
            let kycStatus = KYCStatus(rawValue: kycStatusString),
            let createdAtTimestamp = dict["createdAt"] as? TimeInterval,
            let updatedAtTimestamp = dict["updatedAt"] as? TimeInterval,
            let settlementPeriod = dict["settlementPeriod"] as? Int,
            let transactionFeePercentageValue = dict["transactionFeePercentage"] as? Double,
            let flatFeeCents = dict["flatFeeCents"] as? Int
        else {
            return nil
        }
        
        let transactionFeePercentage = Decimal(transactionFeePercentageValue)
        
        let contactPhone = dict["contactPhone"] as? String
        let address = dict["address"] as? String
        let taxId = dict["taxId"] as? String
        let websiteUrl = dict["websiteUrl"] as? String
        let logoUrl = dict["logoUrl"] as? String
        let businessDescription = dict["businessDescription"] as? String
        
        var bankAccount: BankAccount? = nil
        if let bankAccountDict = dict["bankAccount"] as? [String: Any] {
            bankAccount = BankAccount.fromDictionary(bankAccountDict)
        }
        
        return Merchant(
            id: id,
            name: name,
            businessType: businessType,
            merchantType: merchantType,
            contactEmail: contactEmail,
            contactPhone: contactPhone,
            address: address,
            island: island,
            taxId: taxId,
            bankAccount: bankAccount,
            status: status,
            kycStatus: kycStatus,
            createdAt: Date(timeIntervalSince1970: createdAtTimestamp),
            updatedAt: Date(timeIntervalSince1970: updatedAtTimestamp),
            websiteUrl: websiteUrl,
            logoUrl: logoUrl,
            businessDescription: businessDescription,
            settlementPeriod: settlementPeriod,
            transactionFeePercentage: transactionFeePercentage,
            flatFeeCents: flatFeeCents,
            firebaseId: id
        )
    }
}

// MARK: - Bank Account
struct BankAccount: Codable {
    var bankName: String
    var bankType: BankType
    var accountNumber: String
    var accountName: String
    var routingNumber: String?
    var iban: String?
    var swift: String?
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "bankName": bankName,
            "bankType": bankType.rawValue,
            "accountNumber": accountNumber,
            "accountName": accountName
        ]
        
        if let routingNumber = routingNumber { dict["routingNumber"] = routingNumber }
        if let iban = iban { dict["iban"] = iban }
        if let swift = swift { dict["swift"] = swift }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> BankAccount? {
        guard
            let bankName = dict["bankName"] as? String,
            let bankTypeString = dict["bankType"] as? String,
            let bankType = BankType(rawValue: bankTypeString),
            let accountNumber = dict["accountNumber"] as? String,
            let accountName = dict["accountName"] as? String
        else {
            return nil
        }
        
        let routingNumber = dict["routingNumber"] as? String
        let iban = dict["iban"] as? String
        let swift = dict["swift"] as? String
        
        return BankAccount(
            bankName: bankName,
            bankType: bankType,
            accountNumber: accountNumber,
            accountName: accountName,
            routingNumber: routingNumber,
            iban: iban,
            swift: swift
        )
    }
}

// MARK: - POS Terminal
struct POSTerminal: Identifiable, Codable {
    var id: String
    var serialNumber: String
    var model: String
    var activationDate: Date
    var isActive: Bool
    var lastSyncDate: Date?
    var merchantId: String
    var firmwareVersion: String
    var location: String?
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "serialNumber": serialNumber,
            "model": model,
            "activationDate": activationDate.timeIntervalSince1970,
            "isActive": isActive,
            "merchantId": merchantId,
            "firmwareVersion": firmwareVersion
        ]
        
        if let lastSyncDate = lastSyncDate {
            dict["lastSyncDate"] = lastSyncDate.timeIntervalSince1970
        }
        
        if let location = location {
            dict["location"] = location
        }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any], id: String) -> POSTerminal? {
        guard
            let serialNumber = dict["serialNumber"] as? String,
            let model = dict["model"] as? String,
            let activationDateTimestamp = dict["activationDate"] as? TimeInterval,
            let isActive = dict["isActive"] as? Bool,
            let merchantId = dict["merchantId"] as? String,
            let firmwareVersion = dict["firmwareVersion"] as? String
        else {
            return nil
        }
        
        let lastSyncDateTimestamp = dict["lastSyncDate"] as? TimeInterval
        let lastSyncDate = lastSyncDateTimestamp.map { Date(timeIntervalSince1970: $0) }
        
        let location = dict["location"] as? String
        
        return POSTerminal(
            id: id,
            serialNumber: serialNumber,
            model: model,
            activationDate: Date(timeIntervalSince1970: activationDateTimestamp),
            isActive: isActive,
            lastSyncDate: lastSyncDate,
            merchantId: merchantId,
            firmwareVersion: firmwareVersion,
            location: location
        )
    }
} 