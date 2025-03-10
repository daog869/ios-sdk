import SwiftUI
import Combine

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: AppError?
    @State private var showingForgotPassword = false
    @State private var showingSignUp = false
    @State private var rememberMe = false
    
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Logo and header
                VStack(spacing: 16) {
                    Image(systemName: "creditcard.and.123")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    Text("VIZION GATEWAY")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Payment Processing Platform")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                
                // Login Form
                VStack(spacing: 24) {
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .placeholder(when: email.isEmpty) {
                                Text("Enter your email")
                                    .foregroundColor(.gray.opacity(0.7))
                                    .padding(.leading, 16)
                            }
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        SecureField("Enter your password", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Remember me & Forgot password
                    HStack {
                        Toggle("Remember me", isOn: $rememberMe)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                        
                        Spacer()
                        
                        Button("Forgot Password?") {
                            showingForgotPassword = true
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                    
                    // Login button
                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        } else {
                            Text("Log In")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(isLoading || !isFormValid)
                    .padding(.top, 16)
                    
                    // Sign Up button
                    Button(action: { showingSignUp = true }) {
                        HStack {
                            Text("Don't have an account?")
                                .foregroundColor(.secondary)
                            Text("Sign Up")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 24)
                }
                .padding(.horizontal, 24)
                
                // Environment indicator (Sandbox/Production)
                if let environment = UserDefaults.standard.string(forKey: "environment"),
                   environment == "sandbox" {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Sandbox Environment")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.top, 40)
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .withErrorHandling($errorMessage)
        .sheet(isPresented: $showingForgotPassword) {
            PasswordResetView()
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
                .environmentObject(AuthenticationManager.shared)
        }
    }
    
    // MARK: - Form Validation
    
    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6
    }
    
    // MARK: - Authentication
    
    private func login() {
        isLoading = true
        
        Task {
            do {
                // Call authentication service
                let user = try await FirebaseManager.shared.signIn(email: email, password: password)
                
                // Store user session
                authManager.setCurrentUser(user)
                
                // Save credentials if "remember me" is selected
                if rememberMe {
                    authManager.saveCredentials(email: email, password: password)
                }
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = AppError.from(error)
                    isLoading = false
                }
            }
        }
    }
}

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: AppError?
    @State private var isSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Reset Your Password")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                Text("Enter your email address and we'll send you instructions to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.headline)
                    
                    TextField("your@email.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.top, 16)
                
                // Reset button
                Button(action: resetPassword) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    } else {
                        Text("Send Reset Link")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .disabled(isLoading || email.isEmpty || !email.contains("@"))
                .padding(.top, 16)
                
                if isSuccess {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                        
                        Text("Reset link sent!")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text("Check your email for instructions to reset your password.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.top, 16)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .withErrorHandling($errorMessage)
    }
    
    private func resetPassword() {
        guard !email.isEmpty, email.contains("@") else { return }
        
        isLoading = true
        
        Task {
            do {
                try await FirebaseManager.shared.resetPassword(for: email)
                
                await MainActor.run {
                    isSuccess = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = AppError.from(error)
                    isLoading = false
                }
            }
        }
    }
}

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: AppError?
    @State private var role: UserRole = .customer
    
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Create Your Account")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 16)
                    
                    // First Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("First Name")
                            .font(.headline)
                        
                        TextField("John", text: $firstName)
                            .textContentType(.givenName)
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Last Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Name")
                            .font(.headline)
                        
                        TextField("Doe", text: $lastName)
                            .textContentType(.familyName)
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                        
                        TextField("your@email.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                        
                        SecureField("Choose a password", text: $password)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Confirm Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.headline)
                        
                        SecureField("Confirm your password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Role Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account Type")
                            .font(.headline)
                        
                        Picker("Select your account type", selection: $role) {
                            Text("Customer").tag(UserRole.customer)
                            Text("Merchant").tag(UserRole.merchant)
                            Text("Admin").tag(UserRole.admin)
                            Text("Bank").tag(UserRole.bank)
                        }
                        .pickerStyle(.menu)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Sign Up button
                    Button(action: createAccount) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(isLoading || !isFormValid)
                    .padding(.top, 16)
                    
                    // Terms and conditions
                    Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .withErrorHandling($errorMessage)
    }
    
    // MARK: - Form Validation
    
    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty &&
        !email.isEmpty && email.contains("@") && 
        password.count >= 6 && password == confirmPassword
    }
    
    // MARK: - Authentication
    
    private func createAccount() {
        isLoading = true
        
        Task {
            do {
                // Call authentication service to create account
                let user = try await FirebaseManager.shared.createAccount(
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName,
                    role: role
                )
                
                // Store user session
                authManager.setCurrentUser(user)
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = AppError.from(error)
                    isLoading = false
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthenticationManager())
    }
}

// MARK: - View Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
} 