import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

class APIService: ObservableObject {
    static let shared = APIService()
    private let db = Firestore.firestore()
    private let baseURL = "https://api.viziongateway.com/v1"
    
    // MARK: - API Key Management
    
    func generateAPIKey(
        name: String,
        environment: AppEnvironment,
        scopes: Set<APIScope>? = nil,
        expiresAt: Date? = nil,
        ipRestrictions: [String]? = nil,
        metadata: [String: String]? = nil
    ) async throws -> APIKey {
        guard let currentUser = Auth.auth().currentUser else {
            throw VizionAppError.authError("User not authenticated")
        }
        
        // Generate a secure random key with environment prefix
        let keyString = "vz_\(environment == .production ? "live" : "test")_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        
        // Create API key document
        let ref = db.collection("apiKeys").document()
        var keyData: [String: Any] = [
            "key": keyString,
            "name": name,
            "merchantId": currentUser.uid,
            "active": true,
            "createdAt": Timestamp(date: Date()),
            "environment": environment.rawValue,
            "scopes": (scopes ?? Set(APIScope.allCases)).map { $0.rawValue }
        ]
        
        // Add optional fields
        if let expiresAt = expiresAt {
            keyData["expiresAt"] = Timestamp(date: expiresAt)
        }
        
        if let ipRestrictions = ipRestrictions {
            keyData["ipRestrictions"] = ipRestrictions
        }
        
        if let metadata = metadata {
            keyData["metadata"] = metadata
        }
        
        try await ref.setData(keyData)
        
        return APIKey(
            id: ref.documentID,
            name: name,
            key: keyString,
            createdAt: Date(),
            environment: environment,
            lastUsed: nil,
            scopes: scopes ?? Set(APIScope.allCases),
            active: true,
            merchantId: currentUser.uid,
            expiresAt: expiresAt,
            ipRestrictions: ipRestrictions,
            metadata: metadata
        )
    }
    
    func revokeAPIKey(_ keyId: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw VizionAppError.authError("User not authenticated")
        }
        
        // Verify ownership
        let doc = try await db.collection("apiKeys").document(keyId).getDocument()
        guard let data = doc.data(),
              let merchantId = data["merchantId"] as? String,
              merchantId == currentUser.uid else {
            throw VizionAppError.permissionError("Not authorized to revoke this API key")
        }
        
        try await db.collection("apiKeys").document(keyId).updateData([
            "active": false
        ])
    }
    
    // MARK: - Webhook Management
    
    func registerWebhook(url: URL, events: [String]) async throws -> WebhookEndpoint {
        guard let currentUser = Auth.auth().currentUser else {
            throw VizionAppError.authError("User not authenticated")
        }
        
        let webhookId = UUID().uuidString
        
        // Get current environment
        let currentEnvironment = UserDefaults.standard.string(forKey: "environment").flatMap { AppEnvironment(rawValue: $0) } ?? .sandbox

        let webhookData: [String: Any] = [
            "id": webhookId,
            "url": url.absoluteString,
            "events": events,
            "merchantId": currentUser.uid,
            "createdAt": Timestamp(date: Date()),
            "environment": currentEnvironment.rawValue,
            "isActive": true
        ]
        
        try await db.collection("webhooks").document(webhookId).setData(webhookData)
        
        return WebhookEndpoint(
            id: webhookId,
            url: url.absoluteString,
            events: events,
            isActive: true,
            createdAt: Date(),
            merchantId: currentUser.uid,
            environment: currentEnvironment,
            lastAttempt: nil,
            lastSuccess: nil,
            failureCount: 0
        )
    }
    
    func updateWebhook(_ webhookId: String, isActive: Bool) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw VizionAppError.authError("User not authenticated")
        }
        
        // Verify ownership
        let doc = try await db.collection("webhooks").document(webhookId).getDocument()
        guard let data = doc.data(),
              let merchantId = data["merchantId"] as? String,
              merchantId == currentUser.uid else {
            throw VizionAppError.permissionError("Not authorized to update this webhook")
        }
        
        try await db.collection("webhooks").document(webhookId).updateData([
            "isActive": isActive
        ])
    }
    
    // MARK: - Test Transaction
    
    func createTestTransaction(amount: Decimal, currency: String, paymentMethod: String) async throws -> Transaction {
        guard let currentUser = Auth.auth().currentUser else {
            throw VizionAppError.authError("User not authenticated")
        }
        
        let transactionId = "test_\(UUID().uuidString)"
        let amountInCents = NSDecimalNumber(decimal: amount * 100).intValue
        
        let transactionData: [String: Any] = [
            "id": transactionId,
            "amount": amountInCents,
            "currency": currency,
            "paymentMethod": paymentMethod,
            "merchantId": currentUser.uid,
            "status": "pending",
            "environment": "sandbox",
            "createdAt": Timestamp(date: Date())
        ]
        
        try await db.collection("transactions").document(transactionId).setData(transactionData)
        
        // Simulate processing
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Update to success
        try await db.collection("transactions").document(transactionId).updateData([
            "status": "succeeded",
            "updatedAt": Timestamp(date: Date())
        ])
        
        return Transaction(
            id: transactionId,
            amount: amount,
            currency: currency,
            status: .completed,
            type: .payment,
            paymentMethod: PaymentMethod(rawValue: paymentMethod) ?? .creditCard,
            timestamp: Date(),
            merchantId: currentUser.uid,
            merchantName: "Test Merchant",
            reference: transactionId
        )
    }
    
    // MARK: - Test Webhook
    
    func sendTestWebhook(url: URL, event: String, payload: [String: Any]?) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw VizionAppError.authError("User not authenticated")
        }
        
        var finalPayload: [String: Any] = [
            "id": "evt_\(UUID().uuidString)",
            "type": event,
            "created": Int(Date().timeIntervalSince1970),
            "merchantId": currentUser.uid,
            "livemode": false
        ]
        
        if let customPayload = payload {
            finalPayload["data"] = customPayload
        }
        
        // Create webhook attempt record
        let attemptId = UUID().uuidString
        let attemptData: [String: Any] = [
            "id": attemptId,
            "url": url.absoluteString,
            "event": event,
            "payload": finalPayload,
            "merchantId": currentUser.uid,
            "createdAt": Timestamp(date: Date()),
            "status": "pending"
        ]
        
        try await db.collection("webhookAttempts").document(attemptId).setData(attemptData)
        
        // Trigger Cloud Function to send webhook
        let functions = Functions.functions()
        try await functions.httpsCallable("sendWebhook").call([
            "attemptId": attemptId
        ])
    }
    
    // MARK: - API Logs
    
    func fetchAPILogs() async throws -> [APILogEntry] {
        guard let currentUser = Auth.auth().currentUser else {
            throw VizionAppError.authError("User not authenticated")
        }
        
        let snapshot = try await db.collection("apiLogs")
            .whereField("merchantId", isEqualTo: currentUser.uid)
            .order(by: "timestamp", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> APILogEntry? in
            let data = doc.data()
            guard let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
                  let method = data["method"] as? String,
                  let path = data["path"] as? String,
                  let statusCode = data["statusCode"] as? Int,
                  let duration = data["duration"] as? TimeInterval,
                  let environment = data["environment"] as? String else {
                return nil
            }
            
            return APILogEntry(
                id: doc.documentID,
                timestamp: timestamp,
                method: method,
                path: path,
                statusCode: statusCode,
                duration: duration,
                merchantId: currentUser.uid,
                environment: AppEnvironment(rawValue: environment) ?? .sandbox,
                requestBody: data["requestBody"] as? String,
                responseBody: data["responseBody"] as? String,
                errorMessage: data["errorMessage"] as? String
            )
        }
    }
} 
