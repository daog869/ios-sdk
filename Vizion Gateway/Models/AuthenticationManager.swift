import SwiftUI
import LocalAuthentication
import SwiftData
import Combine

// MARK: - Deprecated
@available(*, deprecated, message: "Use AuthorizationManager instead")
@Observable
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    var currentUser: User?
    var isAuthenticated = false
    var isBiometricAvailable = false
    var authError: String?
    
    private let context = LAContext()
    
    init() {
        checkBiometricAvailability()
    }
    
    func setCurrentUser(_ user: User) {
        self.currentUser = user
        self.isAuthenticated = true
    }
    
    func saveCredentials(email: String, password: String) {
        // In a real app, you would use Keychain to securely store credentials
        UserDefaults.standard.set(email, forKey: "savedEmail")
        // Never store password in UserDefaults in a real app - this is for demo only
        print("Credentials saved for \(email)")
    }
    
    private func checkBiometricAvailability() {
        var error: NSError?
        isBiometricAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func authenticateWithBiometrics() async -> Bool {
        guard isBiometricAvailable else { return false }
        
        do {
            let reason = "Log in to VIZION Gateway"
            try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            await MainActor.run {
                isAuthenticated = true
                authError = nil
            }
            return true
        } catch {
            await MainActor.run {
                authError = error.localizedDescription
            }
            return false
        }
    }
    
    func login(email: String, password: String, modelContext: ModelContext) async -> Bool {
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // In a real app, validate credentials against backend
        let fetchDescriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.email == email
            }
        )
        
        do {
            let users = try modelContext.fetch(fetchDescriptor)
            if let user = users.first {
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                    user.lastLogin = Date()
                    authError = nil
                }
                try? modelContext.save()
                return true
            } else {
                await MainActor.run {
                    authError = "Invalid credentials"
                }
                return false
            }
        } catch {
            await MainActor.run {
                authError = error.localizedDescription
            }
            return false
        }
    }
    
    func register(
        firstName: String,
        lastName: String,
        email: String,
        password: String,
        phoneNumber: String,
        address: String,
        role: UserRole,
        modelContext: ModelContext
    ) async -> Bool {
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // In a real app, validate and create user on backend
        let fetchDescriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.email == email
            }
        )
        
        do {
            let existingUsers = try modelContext.fetch(fetchDescriptor)
            guard existingUsers.isEmpty else {
                await MainActor.run {
                    authError = "Email already exists"
                }
                return false
            }
            
            let user = User(
                firstName: firstName,
                lastName: lastName,
                email: email,
                phone: phoneNumber,
                role: role,
                isActive: true,
                createdAt: Date(),
                address: address
            )
            
            // In a real app, you'd add additional security validation for admin roles
            // and potentially require approval from existing admins
            
            modelContext.insert(user)
            try modelContext.save()
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                authError = nil
            }
            
            return true
        } catch {
            await MainActor.run {
                authError = error.localizedDescription
            }
            return false
        }
    }
    
    func logout() {
        currentUser = nil
        isAuthenticated = false
        authError = nil
    }
    
    func signOut() {
        // Clear credentials
        UserDefaults.standard.removeObject(forKey: "savedEmail")
        
        // Clear any authentication tokens
        // In a real app, you would also invalidate the token on the server
        
        // Reset local state
        currentUser = nil
        isAuthenticated = false
        authError = nil
        
        // Post notification for app-wide state reset
        NotificationCenter.default.post(name: NSNotification.Name("UserDidSignOut"), object: nil)
    }
    
    func requestTwoFactorCode() async -> String? {
        // Simulate API call to request 2FA code
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        return "123456" // In real app, this would be sent via SMS/email
    }
    
    func verifyTwoFactorCode(_ code: String) async -> Bool {
        // Simulate API call to verify 2FA code
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        return code == "123456" // In real app, validate against backend
    }
}

// MARK: - Supporting Types

enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case biometricsFailed
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .biometricsFailed:
            return "Biometric authentication failed"
        case .networkError:
            return "Network connection error"
        case .unknown:
            return "An unknown error occurred"
        }
    }
} 