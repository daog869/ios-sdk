import Foundation
import SwiftData
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import FirebaseFunctions
import UIKit


// Define error types for Firebase operations
enum FirebaseError: Error {
    case documentNotFound
    case invalidData
    case authenticationRequired
    case networkError
    case unknown(Error)
}

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
    
    private func verifyUserRole() async throws -> String {
        guard let currentUser = auth.currentUser else {
            throw FirebaseError.authenticationRequired
        }
        
        // Force refresh token to ensure we have latest claims
        let tokenResult = try await currentUser.getIDTokenResult(forcingRefresh: true)
        
        // Check if user has role in claims
        if let role = tokenResult.claims["role"] as? String {
            return role
        }
        
        // If no role in claims, check Firestore
        let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
        guard let role = userDoc.data()?["role"] as? String else {
            throw FirebaseError.invalidData
        }
        
        return role
    }
    
    func signIn(email: String, password: String) async throws -> MerchantUser {
        // Firebase authentication
        do {
            let authResult = try await auth.signIn(withEmail: email, password: password)
            let uid = authResult.user.uid
            
            // Update the user's token force refresh to ensure latest permissions
            try await authResult.user.getIDTokenResult(forcingRefresh: true)
            
            // Get user data from Firestore
            let userDoc = try await db.collection("users").document(uid).getDocument()
            
            // Check if user document exists
            if !userDoc.exists {
                print("User document not found for authenticated user: \(uid)")
                
                // Create a default user document since the auth user exists but not the Firestore document
                let defaultUser = MerchantUser(
                    id: uid,
                    firstName: authResult.user.displayName?.components(separatedBy: " ").first ?? "",
                    lastName: authResult.user.displayName?.components(separatedBy: " ").last ?? "",
                    email: email,
                    phone: nil,
                    role: .merchant,
                    isActive: true,
                    createdAt: Date(),
                    lastLogin: Date(),
                    island: nil,
                    address: nil,
                    businessName: nil,
                    firebaseId: uid,
                    isVerified: false,
                    verificationDate: nil
                )
                
                // Save the default user to Firestore
                try await createUser(defaultUser)
                print("Created default user document for: \(uid)")
                
                return defaultUser
            }
            
            guard let userData = userDoc.data(), 
                  let user = MerchantUser.fromDictionary(userData, id: uid) else {
                throw NSError(domain: "FirebaseManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user data"])
            }
            
            // Update the user's last login time
            try await updateUserLastLogin(userId: uid)
            
            print("Successfully signed in user: \(user.email)")
            return user
        } catch {
            print("Firebase sign-in error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // This method ensures the current authentication state is valid
    func validateAuthState() async throws -> Bool {
        guard let currentUser = auth.currentUser else {
            print("No authenticated user found")
            return false
        }
        
        // Force refresh the token to ensure it has current permissions
        do {
            let tokenResult = try await currentUser.getIDTokenResult(forcingRefresh: true)
            print("Token refreshed. Expiration: \(tokenResult.expirationDate)")
            return true
        } catch {
            print("Error refreshing authentication token: \(error.localizedDescription)")
            try auth.signOut() // Sign out if token refresh fails
            throw error
        }
    }
    
    // Monitor authentication state changes
    func monitorAuthState(completion: @escaping (Bool) -> Void) {
        auth.addStateDidChangeListener { _, user in
            completion(user != nil)
        }
    }
    
    func signOut() async throws {
        // Clear any cached data or local state before sign out
        if let context = modelContext {
            try? context.delete(model: APIKey.self)
            try? context.save()
        }
        
        // Reset environment to default
        setEnvironment(.sandbox)
        
        // Remove all listeners
        NotificationCenter.default.post(name: .userWillSignOut, object: nil)
        
        // Perform the actual sign out
        try auth.signOut()
        
        // Clear any sensitive data
        UserDefaults.standard.removeObject(forKey: "environment")
        
        // Post notification that sign out is complete
        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
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
    
    func fetchUser(withId userId: String) async throws -> User? {
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard document.exists, let data = document.data() else {
            return nil
        }
        
        return User.fromDictionary(data, id: userId)
    }
    
    func updateUserLastLogin(userId: String) async throws {
        let ref = db.collection("users").document(userId)
        try await ref.updateData([
            "lastLogin": Date().timeIntervalSince1970
        ])
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
    
    // MARK: - Profile Image Methods
    
    /// Uploads a profile image for the specified user
    /// - Parameters:
    ///   - userId: The ID of the user
    ///   - imageData: The image data to upload
    ///   - progressHandler: Optional closure to track upload progress (0.0 to 1.0)
    /// - Returns: The download URL of the uploaded image
    func uploadProfileImage(userId: String, imageData: Data, progressHandler: ((Double) -> Void)? = nil) async throws -> URL {
        // Create storage reference
        let storageRef = storage.reference()
        let profileImageRef = storageRef.child("\(environment.rawValue)/profiles/\(userId)/profile.jpg")
        
        // Compress image for better storage efficiency
        guard let compressedImageData = compressImage(imageData) else {
            throw FirebaseError.invalidData
        }
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Create upload task
        let uploadTask = profileImageRef.putData(compressedImageData, metadata: metadata)
        
        // Monitor progress
        if let progressHandler = progressHandler {
            uploadTask.observe(.progress) { snapshot in
                guard let progress = snapshot.progress else { return }
                let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                progressHandler(percentComplete)
            }
        }
        
        // Wait for task to complete
        return try await withCheckedThrowingContinuation { continuation in
            uploadTask.observe(.success) { _ in
                Task {
                    do {
                        let downloadURL = try await profileImageRef.downloadURL()
                        
                        // Update user's profile image URL in Firestore
                        if let currentUser = self.auth.currentUser {
                            try await self.db.collection("users").document(currentUser.uid).updateData([
                                "profileImageURL": downloadURL.absoluteString
                            ])
                        }
                        
                        continuation.resume(returning: downloadURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            uploadTask.observe(.failure) { snapshot in
                if let error = snapshot.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: FirebaseError.unknown(NSError(domain: "FirebaseManager", code: 1005, userInfo: [NSLocalizedDescriptionKey: "Unknown upload error"])))
                }
            }
        }
    }
    
    private func compressImage(_ imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        
        // Target size for profile images (512x512 max while maintaining aspect ratio)
        let maxDimension: CGFloat = 512
        let aspectRatio = image.size.width / image.size.height
        
        var targetSize: CGSize
        if aspectRatio > 1 {
            // Width is larger
            targetSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Height is larger or square
            targetSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Resize image
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        // Compress to JPEG
        return resizedImage.jpegData(compressionQuality: 0.7)
    }
    
    // MARK: - Transaction Methods
    
    func getTransactions(limit: Int = 50) async throws -> [Transaction] {
        let role = try await verifyUserRole()
        guard let currentUser = auth.currentUser else {
            throw FirebaseError.authenticationRequired
        }
        
        var query = db.collection("transactions")
            .whereField("environment", isEqualTo: environment.rawValue)
        
        // Only filter by merchantId if not admin
        if role != "admin" {
            query = query.whereField("merchantId", isEqualTo: currentUser.uid)
        }
        
        // Add ordering and limit
        query = query.order(by: "timestamp", descending: true)
        if limit > 0 {
            query = query.limit(to: limit)
        }
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { document in
            Transaction.fromDictionary(document.data(), id: document.documentID)
        }
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
    
    // Fetch a single transaction by ID
    func getTransaction(id: String) async throws -> Transaction {
        let documentSnapshot = try await db.collection("transactions").document(id).getDocument()
        
        guard documentSnapshot.exists, 
              let data = documentSnapshot.data(),
              let transaction = Transaction.fromDictionary(data, id: documentSnapshot.documentID) else {
            throw FirebaseError.documentNotFound
        }
        
        return transaction
    }
    
    // MARK: - User Transaction Methods
    
    func fetchUserTransactions(userId: String) async throws -> [Transaction] {
        let snapshot = try await db.collection("transactions")
            .whereField("customerId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        var transactions: [Transaction] = []
        
        for document in snapshot.documents {
            if let transaction = Transaction.fromDictionary(document.data(), id: document.documentID) {
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
    
    // MARK: - API Key Methods
    
    func generateAPIKey(for merchantId: String, name: String, environment: AppEnvironment) async throws -> String {
        // Generate a unique API key with prefix and random string
        let prefix = environment == .sandbox ? "vz_sk_test" : "vz_sk_live"
        let randomString = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let apiKey = "\(prefix)_\(randomString)"
        
        // Store in Firestore
        let keyData: [String: Any] = [
            "id": UUID().uuidString,
            "name": name,
            "key": apiKey,
            "merchantId": merchantId,
            "environment": environment.rawValue,
            "createdAt": Timestamp(),
            "lastUsed": nil as Timestamp?
        ]
        
        try await db.collection("apiKeys").document().setData(keyData)
        
        return apiKey
    }
    
    func getAPIKeys() async throws -> [APIKey] {
        guard let currentUser = auth.currentUser else {
            throw FirebaseError.authenticationRequired
        }
        
        let snapshot = try await db.collection("apiKeys")
            .whereField("merchantId", isEqualTo: currentUser.uid)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let name = data["name"] as? String,
                  let key = data["key"] as? String,
                  let createdAt = data["createdAt"] as? Timestamp,
                  let environmentString = data["environment"] as? String,
                  let environment = AppEnvironment(rawValue: environmentString) else {
                return nil
            }
            
            let lastUsed = data["lastUsed"] as? Timestamp
            
            return APIKey(
                id: document.documentID,
                name: name,
                key: key,
                createdAt: createdAt.dateValue(),
                environment: environment,
                lastUsed: lastUsed?.dateValue(),
                scopes: Set(APIScope.allCases),
                active: true,
                merchantId: currentUser.uid
            )
        }
    }
    
    func deleteAPIKey(_ keyId: String) async throws {
        try await db.collection("apiKeys").document(keyId).delete()
        
        // Also remove from SwiftData if present
        if let modelContext = modelContext {
            let descriptor = FetchDescriptor<APIKey>(
                predicate: #Predicate<APIKey> { key in
                    key.id == keyId
                }
            )
            if let keyToDelete = try? modelContext.fetch(descriptor).first {
                modelContext.delete(keyToDelete)
            }
        }
    }
    
    func validateAPIKey(_ key: String) async throws -> Bool {
        let snapshot = try await db.collection("apiKeys")
            .whereField("key", isEqualTo: key)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first else {
            return false
        }
        
        // Update last used timestamp
        try await document.reference.updateData([
            "lastUsed": Timestamp()
        ])
        
        return true
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
        let role = try await verifyUserRole()
        guard let currentUser = auth.currentUser else {
            throw FirebaseError.authenticationRequired
        }
        
        // For transactions count and volume
        var transactionsQuery = db.collection("transactions")
            .whereField("environment", isEqualTo: environment.rawValue)
        
        if role != "admin" {
            transactionsQuery = transactionsQuery.whereField("merchantId", isEqualTo: currentUser.uid)
        }
        
        let transactionsSnapshot = try await transactionsQuery.getDocuments()
        let totalTransactions = transactionsSnapshot.documents.count
        
        var totalVolume: Double = 0
        for doc in transactionsSnapshot.documents {
            if let amount = doc.data()["amount"] as? Double {
                totalVolume += amount
            }
        }
        
        // For API integrations
        var integrationsQuery = db.collection("apiKeys")
            .whereField("environment", isEqualTo: environment.rawValue)
        
        if role != "admin" {
            integrationsQuery = integrationsQuery.whereField("merchantId", isEqualTo: currentUser.uid)
        }
        
        let integrationsSnapshot = try await integrationsQuery.getDocuments()
        let activeIntegrations = integrationsSnapshot.documents.count
        
        // Revenue is typically a percentage of the transaction volume
        let revenueAmount = totalVolume * 0.025
        
        return DashboardData(
            totalTransactions: totalTransactions,
            transactionVolume: totalVolume,
            revenueAmount: revenueAmount,
            activeIntegrations: activeIntegrations,
            transactionChange: calculateChange(oldValue: 0.0, newValue: Double(totalTransactions)),
            volumeChange: calculateChange(oldValue: 0.0, newValue: totalVolume),
            revenueChange: calculateChange(oldValue: 0.0, newValue: revenueAmount),
            integrationChange: calculateChange(oldValue: 0.0, newValue: Double(activeIntegrations))
        )
    }
    
    private func calculateChange(oldValue: Double, newValue: Double) -> Double {
        guard oldValue != 0 else { return 0 }
        return ((newValue - oldValue) / oldValue) * 100
    }
    
    func getIntegrations() async throws -> [IntegrationData] {
        guard let currentUser = auth.currentUser else {
            throw FirebaseError.authenticationRequired
        }
        
        let role = try await verifyUserRole()
        
        var query = db.collection("integrations")
            .whereField("environment", isEqualTo: environment.rawValue)
        
        if role != "admin" {
            query = query.whereField("merchantId", isEqualTo: currentUser.uid)
        }
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.map { document in
            let data = document.data()
            return IntegrationData(
                id: document.documentID,
                name: data["name"] as? String ?? "",
                status: IntegrationStatus(rawValue: data["status"] as? String ?? "") ?? .inactive,
                apiVersion: data["apiVersion"] as? String ?? "v1",
                lastActive: (data["lastActive"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
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
    let transactionChange: Double
    let volumeChange: Double
    let revenueChange: Double
    let integrationChange: Double
    
    // Would have more data in a real implementation
}

// Add notification names
extension Notification.Name {
    static let userWillSignOut = Notification.Name("userWillSignOut")
    static let userDidSignOut = Notification.Name("userDidSignOut")
} 
