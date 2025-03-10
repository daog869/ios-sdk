import XCTest
import SwiftData
@testable import Vizion_Gateway
import FirebaseFirestore

final class MerchantModelTests: XCTestCase {
    
    // Test Merchant creation with required fields
    func testMerchantCreation() {
        let merchant = Merchant(
            id: "test123",
            name: "Test Business",
            businessType: "Retail",
            contactEmail: "test@example.com"
        )
        
        XCTAssertEqual(merchant.id, "test123")
        XCTAssertEqual(merchant.name, "Test Business")
        XCTAssertEqual(merchant.businessType, "Retail")
        XCTAssertEqual(merchant.contactEmail, "test@example.com")
        XCTAssertEqual(merchant.status, "Pending")
        XCTAssertNil(merchant.contactPhone)
        XCTAssertNil(merchant.address)
        XCTAssertNil(merchant.taxId)
    }
    
    // Test Merchant creation with all fields
    func testMerchantCreationWithAllFields() {
        let createdAt = Date()
        let merchant = Merchant(
            id: "test456",
            name: "Full Test Business",
            businessType: "Service",
            contactEmail: "full@example.com",
            contactPhone: "+1234567890",
            address: "123 Test St, Test City",
            taxId: "TAX12345",
            status: "Active",
            createdAt: createdAt,
            processingVolume: 5000.50,
            transactionLimit: 10000,
            processingFee: 2.5,
            currency: "USD"
        )
        
        XCTAssertEqual(merchant.id, "test456")
        XCTAssertEqual(merchant.name, "Full Test Business")
        XCTAssertEqual(merchant.businessType, "Service")
        XCTAssertEqual(merchant.contactEmail, "full@example.com")
        XCTAssertEqual(merchant.contactPhone, "+1234567890")
        XCTAssertEqual(merchant.address, "123 Test St, Test City")
        XCTAssertEqual(merchant.taxId, "TAX12345")
        XCTAssertEqual(merchant.status, "Active")
        XCTAssertEqual(merchant.createdAt, createdAt)
        XCTAssertEqual(merchant.processingVolume, 5000.50)
        XCTAssertEqual(merchant.transactionLimit, 10000)
        XCTAssertEqual(merchant.processingFee, 2.5)
        XCTAssertEqual(merchant.currency, "USD")
    }
    
    // Test Merchant toDictionary method
    func testMerchantToDictionary() {
        let merchant = Merchant(
            id: "test789",
            name: "Dictionary Test",
            businessType: "Retail",
            contactEmail: "dict@example.com",
            contactPhone: "+9876543210",
            status: "Active"
        )
        
        let dict = merchant.toDictionary()
        
        XCTAssertEqual(dict["id"] as? String, "test789")
        XCTAssertEqual(dict["name"] as? String, "Dictionary Test")
        XCTAssertEqual(dict["businessType"] as? String, "Retail")
        XCTAssertEqual(dict["contactEmail"] as? String, "dict@example.com")
        XCTAssertEqual(dict["contactPhone"] as? String, "+9876543210")
        XCTAssertEqual(dict["status"] as? String, "Active")
        XCTAssertNotNil(dict["createdAt"])
    }
    
    // Test Merchant fromDictionary method
    func testMerchantFromDictionary() {
        let timestamp = Timestamp(date: Date())
        let dict: [String: Any] = [
            "name": "From Dictionary",
            "businessType": "Restaurant",
            "contactEmail": "from@example.com",
            "status": "Pending",
            "createdAt": timestamp,
            "contactPhone": "+1122334455",
            "processingVolume": 3000.75
        ]
        
        let merchant = Merchant.fromDictionary(dict, id: "fromDict123")
        
        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "fromDict123")
        XCTAssertEqual(merchant?.name, "From Dictionary")
        XCTAssertEqual(merchant?.businessType, "Restaurant")
        XCTAssertEqual(merchant?.contactEmail, "from@example.com")
        XCTAssertEqual(merchant?.status, "Pending")
        XCTAssertEqual(merchant?.contactPhone, "+1122334455")
    }
    
    // Test Merchant fromDictionary with missing required fields
    func testMerchantFromDictionaryWithMissingFields() {
        let incompleteDict: [String: Any] = [
            "name": "Incomplete",
            // Missing businessType
            "contactEmail": "incomplete@example.com"
            // Missing status and createdAt
        ]
        
        let merchant = Merchant.fromDictionary(incompleteDict, id: "incomplete123")
        
        XCTAssertNil(merchant, "Merchant should be nil when required fields are missing")
    }
    
    // Test merchant status enum
    func testMerchantStatusEnum() {
        XCTAssertEqual(MerchantStatus.active.rawValue, "Active")
        XCTAssertEqual(MerchantStatus.pending.rawValue, "Pending")
        XCTAssertEqual(MerchantStatus.suspended.rawValue, "Suspended")
        XCTAssertEqual(MerchantStatus.terminated.rawValue, "Terminated")
        
        XCTAssertEqual(MerchantStatus.active.color, "green")
        XCTAssertEqual(MerchantStatus.pending.color, "orange")
        XCTAssertEqual(MerchantStatus.suspended.color, "red")
        XCTAssertEqual(MerchantStatus.terminated.color, "gray")
    }
} 