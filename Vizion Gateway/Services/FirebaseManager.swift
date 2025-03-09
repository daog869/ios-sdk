import Foundation
import SwiftData
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import FirebaseFunctions

// Import models directly from the module
import Vizion_Gateway

// The FirebaseManager class uses the model types directly without typealiases
class FirebaseManager {
    // Singleton instance
    static let shared = FirebaseManager()
    
    // Properties that will be initialized with Firebase SDKs
    private let db: Firestore
    private let auth: Auth
    private let storage: Storage
    private let functions: Functions
    
    // Current environment - accessing directly from existing enum
    private var environment: AppEnvironment = .sandbox
    
    // ModelContext for SwiftData operations
    private var modelContext: ModelContext?
    
    private init() {
        // Firebase configuration - Only configure if not already configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("Firebase configured in FirebaseManager")
        } else {
            print("Firebase already configured, using existing configuration")
        }
        
        // Get Firebase service instances
        db = Firestore.firestore()
        auth = Auth.auth()
        storage = Storage.storage()
        functions = Functions.functions()
        
        // Load saved environment
        if let savedEnv = UserDefaults.standard.string(forKey: "environment"),
           let env = AppEnvironment(rawValue: savedEnv) {
            environment = env
        }
    }
    
    // MARK: - Configuration
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func setEnvironment(_ environment: AppEnvironment) {
        self.environment = environment
        UserDefaults.standard.set(environment.rawValue, forKey: "environment")
        
        // Configure Firestore to use environment-specific collection prefixes
        let settings = FirestoreSettings()
        db.settings = settings
        
        // Use environment-specific cloud functions
        if environment == .sandbox {
            functions.useEmulator(withHost: "localhost", port: 5001)
        }
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) async throws -> MerchantUser {
        // Firebase authentication
        let authResult = try await auth.signIn(withEmail: email, password: password)
        let uid = authResult.user.uid
        
        // Get user data from Firestore
        let userDoc = try await db.collection("users").document(uid).getDocument()
        
        guard let userData = userDoc.data(), 
              let user = MerchantUser.fromDictionary(userData, id: uid) else {
            throw NSError(domain: "FirebaseManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user data"])
        }
        
        return user
    }
    
    func signOut() async throws {
        try auth.signOut()
    }
    
    func resetPassword(for email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    func createAccount(email: String, password: String, firstName: String, lastName: String, role: UserRole) async throws -> MerchantUser {
        // Create user in Firebase Auth
        let authResult = try await auth.createUser(withEmail: email, password: password)
        let uid = authResult.user.uid
        
        // Create user in Firestore
        let user = MerchantUser(
            id: uid,
            firstName: firstName,
            lastName: lastName,
            email: email,
            role: role,
            isActive: true,
            createdAt: Date(),
            firebaseId: uid
        )
        
        // Add to Firestore
        let userData = user.toDictionary()
        try await db.collection("users").document(uid).setData(userData)
        
        // Add to local SwiftData
        if let modelContext = modelContext {
            modelContext.insert(user)
        }
        
        return user
    }
    
    // MARK: - User Methods
    
    func getUsers() async throws -> [MerchantUser] {
        let snapshot = try await db.collection("users")
            .whereField("environment", isEqualTo: environment.rawValue)
            .getDocuments()
        
        var users: [MerchantUser] = []
        
        for document in snapshot.documents {
            if let user = MerchantUser.fromDictionary(document.data(), id: document.documentID) {
                users.append(user)
            }
        }
        
        return users
    }
    
    func createUser(_ user: MerchantUser) async throws -> MerchantUser {
        // Add to Firestore
        let ref = db.collection("users").document(user.id)
        var userData = user.toDictionary()
        userData["environment"] = environment.rawValue
        
        try await ref.setData(userData)
        
        // Also add to local model
        if let modelContext = modelContext {
            modelContext.insert(user)
        }
        
        return user
    }
    
    func updateUser(_ user: MerchantUser) async throws {
        // Update in Firestore
        let ref = db.collection("users").document(user.id)
        try await ref.updateData(user.toDictionary())
    }
    
    func deleteUser(_ user: MerchantUser) async throws {
        // Delete from Firestore
        let ref = db.collection("users").document(user.id)
        try await ref.delete()
        
        // Delete from local model
        if let modelContext = modelContext {
            modelContext.delete(user)
        }
    }
    
    // MARK: - Transaction Methods
    
    func getTransactions(limit: Int = 50) async throws -> [PaymentTransaction] {
        let snapshot = try await db.collection("transactions")
            .whereField("environment", isEqualTo: environment.rawValue)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        var transactions: [PaymentTransaction] = []
        
        for document in snapshot.documents {
            if let transaction = PaymentTransaction.fromDictionary(document.data(), id: document.documentID) {
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
    
    func createTransaction(_ transaction: PaymentTransaction) async throws -> PaymentTransaction {
        // Add to Firestore
        let ref = db.collection("transactions").document(transaction.id)
        try await ref.setData(transaction.toDictionary())
        
        // Also add to local model
        if let modelContext = modelContext {
            modelContext.insert(transaction)
        }
        
        return transaction
    }
    
    func updateTransaction(_ transaction: PaymentTransaction) async throws {
        // Update in Firestore
        let ref = db.collection("transactions").document(transaction.id)
        try await ref.updateData(transaction.toDictionary())
    }
    
    // MARK: - API Key Methods
    
    func generateAPIKey(for merchantId: String, name: String) async throws -> String {
        // Generate a random key
        let apiKey = "vz_\(environment.rawValue.prefix(1))k_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        
        // Store in Firestore
        let keyData: [String: Any] = [
            "key": apiKey,
            "merchantId": merchantId,
            "name": name,
            "createdAt": Timestamp(),
            "environment": environment.rawValue
        ]
        
        try await db.collection("apiKeys").document().setData(keyData)
        
        return apiKey
    }
    
    // MARK: - Webhook Methods
    
    func registerWebhook(url: URL, events: [String], merchantId: String) async throws -> String {
        let webhookId = "whk_\(UUID().uuidString.prefix(8))"
        
        // Store in Firestore
        let webhookData: [String: Any] = [
            "id": webhookId,
            "url": url.absoluteString,
            "events": events,
            "merchantId": merchantId,
            "createdAt": Timestamp(),
            "environment": environment.rawValue,
            "active": true
        ]
        
        try await db.collection("webhooks").document(webhookId).setData(webhookData)
        
        return webhookId
    }
    
    // MARK: - Storage Methods
    
    func uploadFile(data: Data, path: String, metadata: [String: String]? = nil) async throws -> URL {
        let storageRef = storage.reference()
        
        // Add environment prefix to path
        let environmentPath = "\(environment.rawValue)/\(path)"
        let fileRef = storageRef.child(environmentPath)
        
        // Create metadata if provided
        var storageMetadata: StorageMetadata?
        if let metadata = metadata {
            storageMetadata = StorageMetadata()
            storageMetadata?.customMetadata = metadata
        }
        
        // Upload the data
        let _ = try await fileRef.putDataAsync(data, metadata: storageMetadata)
        
        // Get the download URL
        let downloadURL = try await fileRef.downloadURL()
        return downloadURL
    }
    
    func downloadFile(path: String) async throws -> Data {
        let storageRef = storage.reference()
        
        // Add environment prefix to path
        let environmentPath = "\(environment.rawValue)/\(path)"
        let fileRef = storageRef.child(environmentPath)
        
        // Set maximum size to 10MB
        let maxSize: Int64 = 10 * 1024 * 1024
        let data = try await fileRef.data(maxSize: maxSize)
        
        return data
    }
    
    func deleteFile(path: String) async throws {
        let storageRef = storage.reference()
        
        // Add environment prefix to path
        let environmentPath = "\(environment.rawValue)/\(path)"
        let fileRef = storageRef.child(environmentPath)
        
        try await fileRef.delete()
    }
    
    // MARK: - Cloud Functions
    
    func callFunction<T: Decodable>(name: String, data: [String: Any]) async throws -> T {
        let result = try await functions.httpsCallable(name).call(data)
        
        // Convert result to expected type
        guard let resultData = try? JSONSerialization.data(withJSONObject: result.data as Any) else {
            throw NSError(domain: "FirebaseManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Invalid function result format"])
        }
        
        return try JSONDecoder().decode(T.self, from: resultData)
    }
    
    // MARK: - Dashboard Data Methods
    
    func getDashboardData() async throws -> DashboardData {
        // For transactions count and volume
        let transactionsQuery = db.collection("transactions")
            .whereField("environment", isEqualTo: environment.rawValue)
        
        let transactionsSnapshot = try await transactionsQuery.getDocuments()
        let totalTransactions = transactionsSnapshot.documents.count
        
        var totalVolume: Double = 0
        for doc in transactionsSnapshot.documents {
            if let amount = doc.data()["amount"] as? Double {
                totalVolume += amount
            }
        }
        
        // For API integrations
        let integrationsQuery = db.collection("apiKeys")
            .whereField("environment", isEqualTo: environment.rawValue)
        let integrationsSnapshot = try await integrationsQuery.getDocuments()
        let activeIntegrations = integrationsSnapshot.documents.count
        
        // Revenue is typically a percentage of the transaction volume
        let revenueAmount = totalVolume * 0.025
        
        return DashboardData(
            totalTransactions: totalTransactions,
            transactionVolume: totalVolume,
            revenueAmount: revenueAmount,
            activeIntegrations: activeIntegrations
        )
    }
    
    // MARK: - Batch Operations
    
    func batchWriteTransactions(_ transactions: [PaymentTransaction]) async throws {
        let batch = db.batch()
        
        for transaction in transactions {
            let ref = db.collection("transactions").document(transaction.id)
            batch.setData(transaction.toDictionary(), forDocument: ref)
        }
        
        try await batch.commit()
        
        // Add to local model
        if let modelContext = modelContext {
            for transaction in transactions {
                modelContext.insert(transaction)
            }
        }
    }
    
    // MARK: - Real-time Listeners
    
    @discardableResult
    func listenForTransactions(limit: Int = 20, onChange: @escaping ([PaymentTransaction]) -> Void) -> ListenerRegistration {
        return db.collection("transactions")
            .whereField("environment", isEqualTo: environment.rawValue)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error listening for transactions: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                var transactions: [PaymentTransaction] = []
                
                for document in documents {
                    if let transaction = PaymentTransaction.fromDictionary(document.data(), id: document.documentID) {
                        transactions.append(transaction)
                    }
                }
                
                onChange(transactions)
            }
    }
}

// MARK: - Supporting Types

struct DashboardData {
    let totalTransactions: Int
    let transactionVolume: Double
    let revenueAmount: Double
    let activeIntegrations: Int
    
    // Would have more data in a real implementation
} 
