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
            "name": name,
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
            
            if let merchant = Merchant.fromDictionary(data, id: document.documentID) {
                merchants.append(merchant)
            }
        }
        
        return merchants
    }
    
    func getMerchantDetails(id: String) async throws -> Merchant {
        // Get Firestore reference
        let db = Firestore.firestore()
        
        // Get merchant document
        let document = try await db.collection("merchants").document(id).getDocument()
        
        guard let data = document.data(),
              let merchant = Merchant.fromDictionary(data, id: id) else {
            throw NSError(domain: "MerchantManager", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Merchant not found"
            ])
        }
        
        // Get transactions for this merchant
        let transactionsSnapshot = try await db.collection("transactions")
            .whereField("merchantId", isEqualTo: id)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        var transactions: [Transaction] = []
        
        for transactionDoc in transactionsSnapshot.documents {
            if let transaction = Transaction.fromDictionary(transactionDoc.data(), id: transactionDoc.documentID) {
                transactions.append(transaction)
            }
        }
        
        // Get API keys for this merchant
        let apiKeysSnapshot = try await db.collection("apiKeys")
            .whereField("merchantId", isEqualTo: id)
            .getDocuments()
        
        var apiKeys: [APIKey] = []
        
        for keyDoc in apiKeysSnapshot.documents {
            let keyData = keyDoc.data()
            
            guard let key = keyData["key"] as? String,
                  let name = keyData["name"] as? String,
                  let active = keyData["active"] as? Bool,
                  let timestamp = keyData["createdAt"] as? Timestamp else {
                continue
            }
            
            let apiKey = APIKey(
                id: keyDoc.documentID,
                name: name,
                key: key,
                createdAt: timestamp.dateValue(),
                environment: AppEnvironment(rawValue: keyData["environment"] as? String ?? "sandbox") ?? .sandbox,
                lastUsed: nil,
                scopes: [],
                active: active,
                merchantId: id,
                expiresAt: nil,
                ipRestrictions: nil,
                metadata: nil
            )
            
            apiKeys.append(apiKey)
        }
        
        // Update the merchant with related data
        merchant.transactions = transactions
        merchant.apiKeys = apiKeys
        
        return merchant
    }
    
    func createMerchant(_ merchant: Merchant) async throws -> Merchant {
        // Get Firestore reference
        let db = Firestore.firestore()
        
        // Get current environment
        let environment = UserDefaults.standard.string(forKey: "environment") ?? "sandbox"
        
        // Prepare merchant data
        var merchantData = merchant.toDictionary()
        merchantData["environment"] = environment
        
        // Add to Firestore
        if merchant.id.isEmpty {
            // Create with auto-generated ID
            let ref = db.collection("merchants").document()
            merchant.id = ref.documentID
            merchantData["id"] = merchant.id
            
            try await ref.setData(merchantData)
        } else {
            // Create with specified ID
            let ref = db.collection("merchants").document(merchant.id)
            try await ref.setData(merchantData)
        }
        
        // Generate API key if needed
        if let apiKeys = merchant.apiKeys, apiKeys.isEmpty {
            let apiKey = try await generateAPIKey(for: merchant.id, name: "Default Key")
            merchant.apiKeys = [apiKey]
        }
        
        return merchant
    }
    
    func updateMerchant(_ merchant: Merchant) async throws {
        // Get Firestore reference
        let db = Firestore.firestore()
        
        // Update in Firestore
        let ref = db.collection("merchants").document(merchant.id)
        try await ref.updateData(merchant.toDictionary())
    }
    
    func suspendMerchant(id: String) async throws {
        // Get Firestore reference
        let db = Firestore.firestore()
        
        // Update status to suspended
        let ref = db.collection("merchants").document(id)
        try await ref.updateData([
            "status": "Suspended"
        ])
    }
    
    func activateMerchant(id: String) async throws {
        // Get Firestore reference
        let db = Firestore.firestore()
        
        // Update status to active
        let ref = db.collection("merchants").document(id)
        try await ref.updateData([
            "status": "Active"
        ])
    }
    
    // MARK: - API Key Management
    
    func generateAPIKey(for merchantId: String, name: String) async throws -> APIKey {
        // Get Firestore reference
        let db = Firestore.firestore()
        
        // Get current environment
        let currentEnvironment = UserDefaults.standard.string(forKey: "environment").flatMap { AppEnvironment(rawValue: $0) } ?? .sandbox
        
        // Generate a secure random key
        let keyString = "vz_\(currentEnvironment == .production ? "live" : "test")_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        
        // Create API key document
        let ref = db.collection("apiKeys").document()
        let keyData: [String: Any] = [
            "key": keyString,
            "name": name,
            "merchantId": merchantId,
            "active": true,
            "createdAt": Timestamp(date: Date()),
            "environment": currentEnvironment.rawValue
        ]
        
        try await ref.setData(keyData)
        
        // Return the created API key
        return APIKey(
            id: ref.documentID,
            name: name,
            key: keyString,
            createdAt: Date(),
            environment: currentEnvironment,
            lastUsed: nil,
            scopes: [],
            active: true,
            merchantId: merchantId,
            expiresAt: nil,
            ipRestrictions: nil,
            metadata: nil
        )
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

// These are already defined in Models/Merchant.swift
// struct Merchant: Identifiable { ... } 
// struct APIKey: Identifiable { ... }

// Use typealias to clarify the usage if needed
typealias MerchantOnboardingResult = [String: String] 