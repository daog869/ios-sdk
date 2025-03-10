import Foundation
import FirebaseAuth
import SwiftData
import SwiftUI

// MARK: - Authorization Manager

class AuthorizationManager: ObservableObject {
    static let shared = AuthorizationManager()
    
    @Published var currentUser: User?
    @Published var authState: AuthState = .initializing
    @Published private(set) var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    enum AuthState {
        case initializing, signedIn, signedOut
    }
    
    private init() {
        setupAuthStateListener()
    }
    
    // MARK: - Auth State Management
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            if let user = user {
                self.validateAndFetchUserData(for: user)
            } else {
                DispatchQueue.main.async {
                    self.currentUser = nil
                    self.authState = .signedOut
                }
            }
        }
    }
    
    private func validateAndFetchUserData(for authUser: FirebaseAuth.User) {
        Task {
            do {
                // First ensure token is valid and refreshed
                let tokenResult = try await authUser.getIDTokenResult(forcingRefresh: true)
                print("Token validated and refreshed. Expires: \(tokenResult.expirationDate)")
                
                // Then fetch user data
                if let user = try await FirebaseManager.shared.fetchUser(withId: authUser.uid) {
                    // User document exists, proceed normally
                    await MainActor.run {
                        self.currentUser = user
                        self.authState = .signedIn
                    }
                    
                    // Update the last login timestamp
                    try await FirebaseManager.shared.updateUserLastLogin(userId: authUser.uid)
                } else {
                    // User document doesn't exist, create a default one
                    print("User document not found for authenticated user: \(authUser.uid)")
                    
                    // Create a default user document since the auth user exists but not the Firestore document
                    let defaultUser = MerchantUser(
                        id: authUser.uid,
                        firstName: authUser.displayName?.components(separatedBy: " ").first ?? "",
                        lastName: authUser.displayName?.components(separatedBy: " ").last ?? "",
                        email: authUser.email ?? "",
                        phone: nil,
                        role: .merchant,
                        isActive: true,
                        createdAt: Date(),
                        lastLogin: Date(),
                        island: nil,
                        address: nil,
                        businessName: nil,
                        firebaseId: authUser.uid,
                        isVerified: false,
                        verificationDate: nil
                    )
                    
                    // Save the default user to Firestore
                    try await FirebaseManager.shared.createUser(defaultUser)
                    print("Created default user document for: \(authUser.uid)")
                    
                    await MainActor.run {
                        self.currentUser = defaultUser
                        self.authState = .signedIn
                    }
                }
            } catch {
                print("Error during user validation and data fetch: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                    self.authState = .signedOut
                }
            }
        }
    }
    
    // MARK: - Authorization Methods
    
    func signIn(email: String, password: String) async throws {
        do {
            // Use FirebaseManager.shared.signIn which handles token refresh
            let merchantUser = try await FirebaseManager.shared.signIn(email: email, password: password)
            
            // Convert to User model if needed
            let user = User(
                id: merchantUser.id,
                firstName: merchantUser.firstName,
                lastName: merchantUser.lastName,
                email: merchantUser.email,
                phone: merchantUser.phone,
                role: merchantUser.role,
                isActive: merchantUser.isActive,
                createdAt: merchantUser.createdAt,
                lastLogin: Date()
            )
            
            await MainActor.run {
                self.currentUser = user
                self.authState = .signedIn
                self.errorMessage = nil
            }
            
            print("User signed in successfully: \(user.id)")
        } catch {
            print("Sign in error: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = self.translateAuthError(error)
            }
            throw error
        }
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String, phone: String? = nil) async throws -> User {
        do {
            // Create the user in Firebase Auth
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            let userId = authResult.user.uid
            
            // Create the user model
            let newUser = User(
                id: userId,
                firstName: firstName,
                lastName: lastName,
                email: email,
                phone: phone,
                role: .customer, // Default role for new sign-ups
                isActive: true,
                createdAt: Date(),
                lastLogin: Date()
            )
            
            // Save user to Firestore
            try await FirebaseManager.shared.createUser(newUser)
            
            await MainActor.run {
                self.currentUser = newUser
                self.authState = .signedIn
                self.errorMessage = nil
            }
            
            return newUser
        } catch {
            print("Sign up error: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = self.translateAuthError(error)
            }
            throw error
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            
            DispatchQueue.main.async {
                self.currentUser = nil
                self.authState = .signedOut
                self.errorMessage = nil
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to sign out. Please try again."
            }
        }
    }
    
    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            await MainActor.run {
                self.errorMessage = nil
            }
        } catch {
            print("Password reset error: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = self.translateAuthError(error)
            }
            throw error
        }
    }
    
    func updatePassword(currentPassword: String, newPassword: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user found"])
        }
        
        // Re-authenticate user before changing password
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        
        do {
            try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: newPassword)
            
            await MainActor.run {
                self.errorMessage = nil
            }
        } catch {
            print("Update password error: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = self.translateAuthError(error)
            }
            throw error
        }
    }
    
    // MARK: - Role-Based Access Control
    
    /// Checks if the current user has the required permission
    func hasPermission(_ permission: Permission) -> Bool {
        guard let user = currentUser else { return false }
        
        // Return the permission check based on the user's role
        return permissionMap[user.role]?.contains(permission) ?? false
    }
    
    /// Permission enum defining all app actions requiring authorization
    enum Permission: String, CaseIterable {
        // User Management
        case viewUsers
        case createUser
        case updateUser
        case deleteUser
        
        // Merchant Management
        case viewMerchants
        case createMerchant
        case updateMerchant
        case deleteMerchant
        
        // Transaction Management
        case viewTransactions
        case createTransaction
        case updateTransaction
        case deleteTransaction
        case processRefund
        case handleDispute
        
        // Analytics
        case viewAnalytics
        case exportReports
        
        // Settings
        case updateSystemSettings
    }
    
    /// Maps user roles to their allowed permissions
    private let permissionMap: [UserRole: Set<Permission>] = [
        .admin: Set(Permission.allCases),
        
        .merchant: [
            .viewTransactions, .createTransaction, .updateTransaction, 
            .processRefund, .viewAnalytics, .updateUser
        ],
        
        .customer: [
            .viewTransactions, .createTransaction
        ],
        
        .bank: [
            .viewTransactions, .processRefund, .handleDispute,
            .viewMerchants, .viewUsers, .viewAnalytics
        ],
        
        .viewer: [
            .viewTransactions, .viewMerchants, .viewUsers, .viewAnalytics
        ]
    ]
    
    // MARK: - Error Handling
    
    private func translateAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        
        if let authErrorCode = AuthErrorCode(_bridgedNSError: nsError) {
            switch authErrorCode.code {
            case .invalidEmail:
                return "The email address is invalid."
            case .wrongPassword:
                return "The password is incorrect."
            case .userNotFound:
                return "No account found with this email address."
            case .userDisabled:
                return "This account has been disabled."
            case .emailAlreadyInUse:
                return "This email address is already in use."
            case .weakPassword:
                return "The password is too weak. Please use at least 6 characters."
            case .networkError:
                return "Network error. Please check your internet connection."
            case .tooManyRequests:
                return "Too many requests. Please try again later."
            default:
                return "An error occurred: \(error.localizedDescription)"
            }
        } else {
            return "An error occurred: \(error.localizedDescription)"
        }
    }
    
    // Add a method to validate permissions before accessing protected data
    func validateUserPermission(_ permission: Permission) async throws -> Bool {
        guard let user = currentUser else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required"])
        }
        
        // Check if we need to refresh the token
        guard let authUser = Auth.auth().currentUser else {
            // No Firebase user, despite having a currentUser
            await MainActor.run {
                self.errorMessage = "Your session has expired. Please sign in again."
                self.authState = .signedOut
            }
            return false
        }
        
        do {
            // Force refresh token to ensure latest permissions
            _ = try await authUser.getIDTokenResult(forcingRefresh: true)
            
            // Check the actual permission
            let hasPermission = permissionMap[user.role]?.contains(permission) ?? false
            
            if !hasPermission {
                print("Permission denied: \(permission.rawValue) for role \(user.role.rawValue)")
                await MainActor.run {
                    self.errorMessage = "You don't have permission to perform this action."
                }
            }
            
            return hasPermission
        } catch {
            print("Token refresh error: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Authentication error: \(error.localizedDescription)"
                self.signOut()
            }
            return false
        }
    }
}

// MARK: - View Modifier Extensions

extension View {
    /// Adds authorization check to a view. If the user doesn't have the required permission, 
    /// the view is replaced with an unauthorized message.
    func requirePermission(_ permission: AuthorizationManager.Permission) -> some View {
        self.modifier(PermissionRequirementModifier(requiredPermission: permission))
    }
}

struct PermissionRequirementModifier: ViewModifier {
    @ObservedObject private var authManager = AuthorizationManager.shared
    let requiredPermission: AuthorizationManager.Permission
    
    func body(content: Content) -> some View {
        Group {
            if authManager.hasPermission(requiredPermission) {
                content
            } else {
                UnauthorizedAccessView(requiredPermission: requiredPermission)
            }
        }
    }
}

struct UnauthorizedAccessView: View {
    let requiredPermission: AuthorizationManager.Permission
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Access Denied")
                .font(.title)
                .fontWeight(.bold)
            
            Text("You don't have permission to access this feature.")
                .multilineTextAlignment(.center)
            
            Text("Required permission: \(requiredPermission.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            
            Button("Go Back") {
                // Navigate back if possible
            }
            .padding()
            .foregroundColor(.white)
            .background(Color.blue)
            .cornerRadius(8)
            .padding(.top, 20)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
} 
