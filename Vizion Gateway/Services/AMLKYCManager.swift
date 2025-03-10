import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseFunctions
import SwiftData

// MARK: - AML/KYC Manager

/// Manages all Anti-Money Laundering (AML) and Know Your Customer (KYC) processes
class AMLKYCManager: ObservableObject {
    static let shared = AMLKYCManager()
    
    @Published var currentVerificationStatus: KYCVerificationStatus = .notStarted
    @Published var verificationProgress: Double = 0.0
    @Published var verificationSteps: [VerificationStep] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firebaseManager = FirebaseManager.shared
    private let storage = Storage.storage()
    
    private init() {}
    
    // MARK: - Verification Status
    
    func getVerificationStatus(for userId: String) async throws -> KYCVerificationStatus {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let db = Firestore.firestore()
            let docSnapshot = try await db.collection("verifications").document(userId).getDocument()
            
            if docSnapshot.exists, let data = docSnapshot.data() {
                if let statusString = data["status"] as? String,
                   let status = KYCVerificationStatus(rawValue: statusString) {
                    
                    // Calculate progress based on completed steps
                    if let steps = data["steps"] as? [[String: Any]] {
                        let completedSteps = steps.filter { $0["completed"] as? Bool == true }.count
                        let totalSteps = steps.count
                        
                        await MainActor.run {
                            self.verificationProgress = totalSteps > 0 ? Double(completedSteps) / Double(totalSteps) : 0
                            self.currentVerificationStatus = status
                            
                            // Convert steps to our model
                            self.verificationSteps = steps.compactMap { stepData in
                                guard let id = stepData["id"] as? String,
                                      let name = stepData["name"] as? String,
                                      let completed = stepData["completed"] as? Bool else {
                                    return nil
                                }
                                
                                return VerificationStep(
                                    id: id,
                                    name: name,
                                    description: stepData["description"] as? String,
                                    isCompleted: completed,
                                    timestamp: (stepData["timestamp"] as? Timestamp)?.dateValue()
                                )
                            }
                        }
                    }
                    
                    return status
                }
            }
            
            // If no verification record exists, create one
            await MainActor.run {
                self.currentVerificationStatus = .notStarted
                self.verificationProgress = 0
                
                // Initialize default steps
                self.verificationSteps = VerificationStepTemplate.defaultSteps
            }
            
            // Save initial verification status
            try await initializeVerification(for: userId)
            
            return .notStarted
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to get verification status: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    private func initializeVerification(for userId: String) async throws {
        let db = Firestore.firestore()
        
        // Map steps to dictionaries for Firestore
        let stepDicts = VerificationStepTemplate.defaultSteps.map { step in
            return [
                "id": step.id,
                "name": step.name,
                "description": step.description ?? "",
                "completed": false,
                "timestamp": FieldValue.serverTimestamp()
            ]
        }
        
        // Create verification document
        try await db.collection("verifications").document(userId).setData([
            "userId": userId,
            "status": KYCVerificationStatus.notStarted.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "steps": stepDicts,
            "riskScore": 0,
            "notes": ""
        ])
    }
    
    // MARK: - Identity Verification
    
    func uploadIdentityDocument(userId: String, documentType: KYCDocumentType, image: UIImage) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Compress image for upload
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                throw NSError(domain: "KYCError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
            }
            
            // Create storage reference
            let storageRef = storage.reference()
            let documentRef = storageRef.child("kyc/\(userId)/\(documentType.rawValue)_\(UUID().uuidString).jpg")
            
            // Upload image
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            _ = try await documentRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await documentRef.downloadURL()
            
            // Update verification status
            try await updateVerificationStep(for: userId, stepId: documentType.verificationStepId, isCompleted: true)
            
            // Update verification document with document URL
            let db = Firestore.firestore()
            try await db.collection("verifications").document(userId).updateData([
                "documents.\(documentType.rawValue)": [
                    "url": downloadURL.absoluteString,
                    "uploadedAt": FieldValue.serverTimestamp(),
                    "verified": false
                ],
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // Check if this completes the document collection step
            try await checkAndUpdateDocumentCollectionStatus(for: userId)
            
            return downloadURL.absoluteString
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to upload document: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    private func checkAndUpdateDocumentCollectionStatus(for userId: String) async throws {
        let db = Firestore.firestore()
        let docSnapshot = try await db.collection("verifications").document(userId).getDocument()
        
        if let data = docSnapshot.data(),
           let documents = data["documents"] as? [String: Any] {
            
            // Check if we have at least one identity document and one address proof
            let hasIdentity = documents.keys.contains { $0.starts(with: "identity") }
            let hasAddress = documents.keys.contains { $0.starts(with: "address") }
            
            if hasIdentity && hasAddress {
                // Mark document collection step as completed
                try await updateVerificationStep(for: userId, stepId: "document_collection", isCompleted: true)
                
                // Trigger document verification (would connect to a third-party service in production)
                try await triggerDocumentVerification(userId: userId)
            }
        }
    }
    
    private func triggerDocumentVerification(userId: String) async throws {
        // In a real implementation, this would call a third-party service API
        // For this demo, we'll simulate the process with a Firebase Function
        
        let data: [String: Any] = ["userId": userId]
        
        do {
            let _ = try await Functions.functions().httpsCallable("verifyUserDocuments").call(data)
            
            // Update document verification step (in reality, this would be done by the function)
            try await updateVerificationStep(for: userId, stepId: "document_verification", isCompleted: true)
            
            // Update overall verification status
            try await updateVerificationStatus(for: userId, status: .documentVerificationPending)
        } catch {
            print("Error calling document verification: \(error)")
            throw error
        }
    }
    
    // MARK: - AML Screening
    
    func performAMLScreening(userId: String, userData: UserScreeningData) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // In a real implementation, this would call a sanctions/PEP API
            // For this demo, we'll simulate the process
            
            // Store the screening data
            let db = Firestore.firestore()
            try await db.collection("verifications").document(userId).updateData([
                "screeningData": [
                    "fullName": userData.fullName,
                    "dateOfBirth": userData.dateOfBirth,
                    "nationality": userData.nationality,
                    "address": userData.address,
                    "occupation": userData.occupation,
                    "sourceOfFunds": userData.sourceOfFunds,
                    "isPep": userData.isPep,
                    "screenedAt": FieldValue.serverTimestamp()
                ],
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // Simulate risk scoring
            let riskScore = calculateRiskScore(userData: userData)
            try await db.collection("verifications").document(userId).updateData([
                "riskScore": riskScore
            ])
            
            // Update verification step
            try await updateVerificationStep(for: userId, stepId: "aml_screening", isCompleted: true)
            
            // If PEP, mark for enhanced due diligence
            if userData.isPep {
                try await updateVerificationStatus(for: userId, status: .enhancedDueDiligence)
            } else if riskScore > 75 {
                try await updateVerificationStatus(for: userId, status: .enhancedDueDiligence)
            } else {
                try await updateVerificationStatus(for: userId, status: .underReview)
                
                // If all steps are completed, mark as verified
                if await areAllStepsCompleted(for: userId) {
                    try await updateVerificationStatus(for: userId, status: .verified)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to perform AML screening: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    private func calculateRiskScore(userData: UserScreeningData) -> Int {
        var score = 0
        
        // This is a simplified risk scoring model
        // In production, this would be much more comprehensive
        
        // PEP status
        if userData.isPep {
            score += 40
        }
        
        // High-risk countries
        let highRiskCountries = ["Country1", "Country2", "Country3"]
        if highRiskCountries.contains(userData.nationality) {
            score += 30
        }
        
        // High-risk occupations
        let highRiskOccupations = ["Politician", "Arms dealer", "Casino operator"]
        if highRiskOccupations.contains(userData.occupation) {
            score += 20
        }
        
        // Source of funds
        let highRiskSources = ["Inheritance", "Investment returns", "Gift"]
        if highRiskSources.contains(userData.sourceOfFunds) {
            score += 15
        }
        
        return min(score, 100)
    }
    
    // MARK: - Verification Helpers
    
    private func updateVerificationStep(for userId: String, stepId: String, isCompleted: Bool) async throws {
        let db = Firestore.firestore()
        let docRef = db.collection("verifications").document(userId)
        
        let docSnapshot = try await docRef.getDocument()
        
        if let data = docSnapshot.data(),
           var steps = data["steps"] as? [[String: Any]] {
            
            // Find and update the step
            if let index = steps.firstIndex(where: { ($0["id"] as? String) == stepId }) {
                steps[index]["completed"] = isCompleted
                steps[index]["timestamp"] = FieldValue.serverTimestamp()
                
                try await docRef.updateData([
                    "steps": steps,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                
                // Update local steps
                await MainActor.run {
                    if let localIndex = self.verificationSteps.firstIndex(where: { $0.id == stepId }) {
                        self.verificationSteps[localIndex].isCompleted = isCompleted
                        self.verificationSteps[localIndex].timestamp = Date()
                        
                        // Update progress
                        let completedSteps = self.verificationSteps.filter { $0.isCompleted }.count
                        self.verificationProgress = Double(completedSteps) / Double(self.verificationSteps.count)
                    }
                }
            }
        }
    }
    
    private func updateVerificationStatus(for userId: String, status: KYCVerificationStatus) async throws {
        let db = Firestore.firestore()
        
        try await db.collection("verifications").document(userId).updateData([
            "status": status.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        await MainActor.run {
            self.currentVerificationStatus = status
        }
    }
    
    private func areAllStepsCompleted(for userId: String) async -> Bool {
        let db = Firestore.firestore()
        let docSnapshot = try? await db.collection("verifications").document(userId).getDocument()
        
        if let data = docSnapshot?.data(),
           let steps = data["steps"] as? [[String: Any]] {
            
            // Check if all required steps are completed
            let requiredSteps = steps.filter { step in
                return step["required"] as? Bool != false
            }
            
            let completedRequiredSteps = requiredSteps.filter { step in
                return step["completed"] as? Bool == true
            }
            
            return completedRequiredSteps.count == requiredSteps.count
        }
        
        return false
    }
    
    // MARK: - Admin Functions
    
    func approveVerification(for userId: String, notes: String = "") async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let db = Firestore.firestore()
            
            try await db.collection("verifications").document(userId).updateData([
                "status": KYCVerificationStatus.verified.rawValue,
                "adminNotes": notes,
                "approvedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            // Also update the user's verification status
            try await db.collection("users").document(userId).updateData([
                "isVerified": true,
                "verificationDate": FieldValue.serverTimestamp()
            ])
            
            await MainActor.run {
                self.currentVerificationStatus = .verified
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to approve verification: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func rejectVerification(for userId: String, reason: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let db = Firestore.firestore()
            
            try await db.collection("verifications").document(userId).updateData([
                "status": KYCVerificationStatus.rejected.rawValue,
                "rejectionReason": reason,
                "rejectedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            await MainActor.run {
                self.currentVerificationStatus = .rejected
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to reject verification: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func requestAdditionalInformation(for userId: String, requestedItems: [String]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let db = Firestore.firestore()
            
            try await db.collection("verifications").document(userId).updateData([
                "status": KYCVerificationStatus.additionalInformationRequired.rawValue,
                "requestedItems": requestedItems,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            await MainActor.run {
                self.currentVerificationStatus = .additionalInformationRequired
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to request additional information: \(error.localizedDescription)"
            }
            throw error
        }
    }
}

// MARK: - Supporting Types

/// User screening data for AML checks
struct UserScreeningData {
    let fullName: String
    let dateOfBirth: Date
    let nationality: String
    let address: String
    let occupation: String
    let sourceOfFunds: String
    let isPep: Bool
} 