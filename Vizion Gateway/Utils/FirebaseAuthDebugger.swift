import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

class FirebaseAuthDebugger {
    static let shared = FirebaseAuthDebugger()
    
    private init() {}
    
    /// Diagnoses common Firebase authentication issues and attempts to fix them
    func diagnoseAndFix() async -> String {
        var diagnosisReport = "Firebase Auth Diagnosis Report\n"
        diagnosisReport += "==========================\n\n"
        
        // Check if user is authenticated
        guard let currentUser = Auth.auth().currentUser else {
            diagnosisReport += "❌ No authenticated user found\n"
            diagnosisReport += "Solution: User needs to sign in\n"
            return diagnosisReport
        }
        
        diagnosisReport += "✅ User is authenticated\n"
        diagnosisReport += "User ID: \(currentUser.uid)\n"
        diagnosisReport += "Email: \(currentUser.email ?? "No email")\n\n"
        
        // Attempt to refresh token
        do {
            diagnosisReport += "🔄 Attempting to refresh authentication token...\n"
            let tokenResult = try await currentUser.getIDTokenResult(forcingRefresh: true)
            
            diagnosisReport += "✅ Token refreshed successfully\n"
            diagnosisReport += "Token expiration: \(tokenResult.expirationDate)\n"
            
            // Check custom claims
            if let claims = tokenResult.claims as? [String: Any] {
                diagnosisReport += "\nCustom claims found:\n"
                claims.forEach { key, value in
                    diagnosisReport += "- \(key): \(value)\n"
                }
            } else {
                diagnosisReport += "⚠️ No custom claims found in token\n"
            }
        } catch {
            diagnosisReport += "❌ Failed to refresh token: \(error.localizedDescription)\n"
            diagnosisReport += "Solution: Sign out and sign in again\n"
        }
        
        // Test Firestore read access
        diagnosisReport += "\n🔄 Testing Firestore access to user document...\n"
        do {
            let userDoc = try await Firestore.firestore().collection("users").document(currentUser.uid).getDocument()
            
            if userDoc.exists {
                diagnosisReport += "✅ Successfully read user document\n"
                
                if let data = userDoc.data() {
                    let role = data["role"] as? String ?? "unknown"
                    diagnosisReport += "User role: \(role)\n"
                    
                    if role != "admin" {
                        diagnosisReport += "⚠️ User does not have admin role which may limit permissions\n"
                    }
                }
            } else {
                diagnosisReport += "❌ User document does not exist\n"
                diagnosisReport += "Solution: Create user document in Firestore\n"
            }
        } catch {
            diagnosisReport += "❌ Failed to read user document: \(error.localizedDescription)\n"
            diagnosisReport += "Solution: Check Firestore security rules\n"
        }
        
        // Provide solution steps
        diagnosisReport += "\nRecommended Actions:\n"
        diagnosisReport += "1. Ensure Firestore rules allow user to access their data\n"
        diagnosisReport += "2. Update the Firestore rules using the template provided\n"
        diagnosisReport += "3. If problems persist, sign out and sign in again\n"
        
        return diagnosisReport
    }
    
    /// Show a debug overlay with auth diagnostics
    func showDebugOverlay() {
        Task {
            let report = await diagnoseAndFix()
            print(report)
            // You could show this in a UI alert/overlay in a real app
        }
    }
    
    /// Reset the authentication state
    func resetAuth() async -> Bool {
        do {
            // Sign out current user
            try Auth.auth().signOut()
            return true
        } catch {
            print("Error signing out: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - SwiftUI View Extension
extension View {
    func withAuthDebugger(isShowing: Binding<Bool>) -> some View {
        self.modifier(AuthDebuggerModifier(isShowing: isShowing))
    }
}

// MARK: - Auth Debugger Modifier
struct AuthDebuggerModifier: ViewModifier {
    @Binding var isShowing: Bool
    @State private var diagnosisReport: String = ""
    @State private var isLoading: Bool = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                VStack {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Firebase Auth Debugger")
                                .font(.headline)
                            Spacer()
                            Button {
                                isShowing = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        ScrollView {
                            Text(diagnosisReport)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                        }
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        HStack {
                            Button("Run Diagnosis") {
                                runDiagnosis()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Spacer()
                            
                            Button("Reset Auth State") {
                                resetAuthState()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .padding(.horizontal, 20)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.2))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.5))
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    runDiagnosis()
                }
            }
        }
    }
    
    private func runDiagnosis() {
        isLoading = true
        diagnosisReport = "Running diagnosis..."
        
        Task {
            diagnosisReport = await FirebaseAuthDebugger.shared.diagnoseAndFix()
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func resetAuthState() {
        isLoading = true
        
        Task {
            let success = await FirebaseAuthDebugger.shared.resetAuth()
            await MainActor.run {
                diagnosisReport += "\n\n" + (success ? "✅ Auth state reset successfully" : "❌ Failed to reset auth state")
                isLoading = false
            }
        }
    }
} 