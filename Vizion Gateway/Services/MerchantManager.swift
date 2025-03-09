import Foundation
import SwiftData
import FirebaseFirestore

class MerchantManager {
    // Singleton instance
    static let shared = MerchantManager()
    
    // Reference to FirebaseManager
    private let firebaseManager = FirebaseManager.shared
    
    // Private initializer
    private init() {}
    
    // MARK: - Merchant Onboarding
    
    func onboardMerchant(name: String, businessType: String, contactEmail: String, 
                         contactPhone: String? = nil, address: String? = nil, 
                         taxId: String? = nil) async throws -> MerchantOnboardingResult {
        // Create merchant data
        var merchantData: [String: Any] = [
            "merchantName": name,
            "businessType": businessType,
            "contactEmail": contactEmail,
            "environment": UserDefaults.standard.string(forKey: "environment") ?? "sandbox"
        ]
        
        // Add optional fields
        if let contactPhone = contactPhone { merchantData["contactPhone"] = contactPhone }
        if let address = address { merchantData["address"] = address }
        if let taxId = taxId { merchantData["taxId"] = taxId }
        
        // Call Firebase function
        let result: MerchantOnboardingResult = try await firebaseManager.callFunction(
            name: "onboardMerchant",
            data: merchantData
        )
        
        return result
    }
    
    // MARK: - Merchant Management
    
    func getMerchants() async throws -> [Merchant] {
        // Get current environment
        let environment = UserDefaults.standard.string(forKey: "environment") ?? "sandbox"
        
        // Get Firestore reference
        let db = Firestore.firestore()
        
        // Query merchants in current environment
        let snapshot = try await db.collection("merchants")
            .whereField("environment", isEqualTo: environment)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        // Parse merchants
        var merchants: [Merchant] = []
        
        for document in snapshot.documents {
            let data = document.data()
            
            guard let id = data["id"] as? String,
                  let name = data["name"] as? String,
                  let businessType = data["businessType"] as? String,
                  let contactEmail = data["contactEmail"] as? String,
                  let status = data["status"] as? String,
                  let timestampValue = data["createdAt"] as? Timestamp else {
                continue
            }
            
            let merchant = Merchant(
                id: id,
                name: name,
                businessType: businessType,
                contactEmail: contactEmail,
                contactPhone: data["contactPhone"] as? String,
                address: data["address"] as? String,
                taxId: data["taxId"] as? String,
                status: status,
                createdAt: timestampValue.dateValue()
            )
            
            merchants.append(merchant)
        }
        
        return merchants
    }
    
    func getMerchantDetails(id: String) async throws -> Merchant {
        // Get Firestore reference
        let db = Firestore.firestore()
        
        // Get merchant document
        let document = try await db.collection("merchants").document(id).getDocument()
        
        guard let data = document.data(),
              let name = data["name"] as? String,
              let businessType = data["businessType"] as? String,
              let contactEmail = data["contactEmail"] as? String,
              let status = data["status"] as? String,
              let timestampValue = data["createdAt"] as? Timestamp else {
            throw NSError(domain: "MerchantManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid merchant data"])
        }
        
        return Merchant(
            id: id,
            name: name,
            businessType: businessType,
            contactEmail: contactEmail,
            contactPhone: data["contactPhone"] as? String,
            address: data["address"] as? String,
            taxId: data["taxId"] as? String,
            status: status,
            createdAt: timestampValue.dateValue()
        )
    }
    
    // MARK: - API Key Management
    
    func getAPIKeys(forMerchant merchantId: String) async throws -> [APIKey] {
        // Get current environment
        let environment = UserDefaults.standard.string(forKey: "environment") ?? "sandbox"
        
        // Get Firestore reference
        let db = Firestore.firestore()
        
        // Query API keys for merchant in current environment
        let snapshot = try await db.collection("apiKeys")
            .whereField("environment", isEqualTo: environment)
            .whereField("merchantId", isEqualTo: merchantId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        // Parse API keys
        var apiKeys: [APIKey] = []
        
        for document in snapshot.documents {
            let data = document.data()
            
            guard let key = data["key"] as? String,
                  let name = data["name"] as? String,
                  let merchantId = data["merchantId"] as? String,
                  let timestampValue = data["createdAt"] as? Timestamp else {
                continue
            }
            
            let active = data["active"] as? Bool ?? false
            
            let apiKey = APIKey(
                id: document.documentID,
                key: key,
                name: name,
                merchantId: merchantId,
                active: active,
                createdAt: timestampValue.dateValue()
            )
            
            apiKeys.append(apiKey)
        }
        
        return apiKeys
    }
    
    func generateAPIKey(for merchantId: String, name: String) async throws -> String {
        // Call Firebase function to generate API key
        let result = try await firebaseManager.generateAPIKey(for: merchantId, name: name)
        return result
    }
    
    func revokeAPIKey(id: String) async throws {
        // Get Firestore reference
        let db = Firestore.firestore()
        
        // Update API key to inactive
        try await db.collection("apiKeys").document(id).updateData([
            "active": false
        ])
    }
}

// MARK: - Supporting Types

struct Merchant: Identifiable {
    let id: String
    let name: String
    let businessType: String
    let contactEmail: String
    let contactPhone: String?
    let address: String?
    let taxId: String?
    let status: String
    let createdAt: Date
}

struct APIKey: Identifiable {
    let id: String
    let key: String
    let name: String
    let merchantId: String
    let active: Bool
    let createdAt: Date
}

struct MerchantOnboardingResult: Codable {
    let merchantId: String
    let merchantName: String
    let status: String
    let message: String
    let apiKey: String
} 