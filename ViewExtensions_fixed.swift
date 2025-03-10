import SwiftUI

// MARK: - Firebase Auth Debugger View Modifier

/// View modifier that adds Firebase authentication debugging functionality
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

// MARK: - View Extensions

extension View {
    /// Adds the Firebase auth debugger to a view
    func withAuthDebugger(isShowing: Binding<Bool>) -> some View {
        self.modifier(AuthDebuggerModifier(isShowing: isShowing))
    }
} 