import SwiftUI
import SwiftData

struct UserProfileView: View {
    @Environment(\.modelContext) private var modelContext
    let user: User
    @State private var isEditing = false
    @State private var firstName: String
    @State private var lastName: String
    @State private var email: String
    @State private var phone: String
    @State private var isLoading = false
    @State private var errorMessage: AppError?
    @State private var showChangePasswordSheet = false
    @State private var showDeleteAccountConfirmation = false
    
    init(user: User) {
        self.user = user
        // Initialize state properties
        _firstName = State(initialValue: user.firstName)
        _lastName = State(initialValue: user.lastName)
        _email = State(initialValue: user.email)
        _phone = State(initialValue: user.phone ?? "")
    }
    
    var body: some View {
        List {
            // Profile header with avatar
            Section {
                HStack(spacing: 16) {
                    // User avatar
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Text(initials)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(user.firstName) \(user.lastName)")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(roleBadgeText)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(roleBadgeColor.opacity(0.2))
                            .foregroundColor(roleBadgeColor)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // Personal information
            Section("Personal Information") {
                if isEditing {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(true)  // Email can't be changed without verification
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                } else {
                    ProfileRow(key: "First Name", value: user.firstName)
                    ProfileRow(key: "Last Name", value: user.lastName)
                    ProfileRow(key: "Email", value: user.email)
                    ProfileRow(key: "Phone", value: user.phone ?? "Not provided")
                }
            }
            
            // Account information
            Section("Account Information") {
                ProfileRow(key: "User ID", value: user.id)
                ProfileRow(key: "Account Type", value: user.role.rawValue.capitalized)
                ProfileRow(key: "Account Status", value: user.isActive ? "Active" : "Inactive")
                
                if let lastLogin = user.lastLogin {
                    ProfileRow(key: "Last Login", value: formatDate(lastLogin))
                }
                
                ProfileRow(key: "Created At", value: formatDate(user.createdAt))
            }
            
            // Security settings
            Section("Security") {
                Button("Change Password") {
                    showChangePasswordSheet = true
                }
                .foregroundColor(.blue)
                
                NavigationLink(destination: IdentityVerificationView()) {
                    HStack {
                        Text("Identity Verification")
                        Spacer()
                        identityVerificationStatusBadge
                    }
                }
                
                Button(role: .destructive) {
                    showDeleteAccountConfirmation = true
                }
            label: {
                    Text("Delete Account")
                        .foregroundColor(.red)
                }
            }
            
            // Sign Out Section
            Section {
                Button(role: .destructive) {
                    signOut()
                } label: {
                    HStack {
                        Spacer()
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveChanges()
                    } else {
                        isEditing = true
                    }
                }
            }
            
            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Reset to original values
                        firstName = user.firstName
                        lastName = user.lastName
                        phone = user.phone ?? ""
                        isEditing = false
                    }
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .sheet(isPresented: $showChangePasswordSheet) {
            ChangePasswordView()
        }
        .withErrorHandling($errorMessage)
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
    
    // MARK: - Helper Properties
    
    private var initials: String {
        let firstInitial = user.firstName.first?.uppercased() ?? ""
        let lastInitial = user.lastName.first?.uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
    
    private var roleBadgeText: String {
        user.role.rawValue.capitalized
    }
    
    private var roleBadgeColor: Color {
        switch user.role {
        case .admin:
            return .red
        case .merchant:
            return .blue
        case .customer:
            return .green
        case .bank:
            return .purple
        case .manager:
            return .orange
        case .analyst:
            return .indigo
        case .viewer:
            return .gray
        }
    }
    
    // Helper views
    private var identityVerificationStatusBadge: some View {
        Group {
            if user.isVerified == true {
                Text("Verified")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
            } else {
                Text("Not Verified")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func saveChanges() {
        isLoading = true
        
        // Validate input
        guard !firstName.isEmpty, !lastName.isEmpty else {
            errorMessage = AppError.validationError("First name and last name are required.")
            isLoading = false
            return
        }
        
        Task {
            do {
                // Update the user object
                user.firstName = firstName
                user.lastName = lastName
                user.phone = phone.isEmpty ? nil : phone
                
                // Update in Firebase
                try await FirebaseManager.shared.updateUser(user)
                
                // Update SwiftData
                try modelContext.save()
                
                await MainActor.run {
                    isEditing = false
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
    
    private func deleteAccount() {
        isLoading = true
        
        Task {
            do {
                // Delete user from Firebase
                try await FirebaseManager.shared.deleteUser(user)
                
                // Delete from SwiftData
                modelContext.delete(user)
                try modelContext.save()
                
                // Sign out
                try await FirebaseManager.shared.signOut()
                
                await MainActor.run {
                    isLoading = false
                    // Return to login screen or handle in an AuthenticationManager
                }
            } catch {
                await MainActor.run {
                    errorMessage = AppError.from(error)
                    isLoading = false
                }
            }
        }
    }
    
    // Actions
    private func signOut() {
        AuthorizationManager.shared.signOut()
    }
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: AppError?
    @State private var isSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Current Password") {
                    SecureField("Current Password", text: $currentPassword)
                        .textContentType(.password)
                }
                
                Section("New Password") {
                    SecureField("New Password", text: $newPassword)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                    
                    // Password strength indicator
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password Strength")
                            .font(.caption)
                        
                        HStack(spacing: 4) {
                            ForEach(0..<4, id: \.self) { index in
                                Rectangle()
                                    .fill(passwordStrengthColor(for: index))
                                    .frame(height: 4)
                            }
                        }
                        
                        Text(passwordStrengthText)
                            .font(.caption)
                            .foregroundColor(passwordStrengthTextColor)
                    }
                    .padding(.top, 8)
                }
                
                Section {
                    Button("Update Password") {
                        changePassword()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(isLoading || !isFormValid)
                }
                
                if isSuccess {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            Text("Password successfully updated")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .withErrorHandling($errorMessage)
        }
    }
    
    // MARK: - Helper Properties
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmPassword
    }
    
    private var passwordStrength: Int {
        var strength = 0
        
        if newPassword.count >= 8 {
            strength += 1
        }
        
        if newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil {
            strength += 1
        }
        
        if newPassword.rangeOfCharacter(from: .decimalDigits) != nil {
            strength += 1
        }
        
        if newPassword.rangeOfCharacter(from: .symbols) != nil {
            strength += 1
        }
        
        return strength
    }
    
    private var passwordStrengthText: String {
        switch passwordStrength {
        case 0: return "Very Weak"
        case 1: return "Weak"
        case 2: return "Moderate"
        case 3: return "Strong"
        case 4: return "Very Strong"
        default: return ""
        }
    }
    
    private var passwordStrengthTextColor: Color {
        switch passwordStrength {
        case 0, 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        default: return .gray
        }
    }
    
    private func passwordStrengthColor(for index: Int) -> Color {
        if passwordStrength > index {
            switch passwordStrength {
            case 1: return .red
            case 2: return .orange
            case 3: return .yellow
            case 4: return .green
            default: return .gray.opacity(0.3)
            }
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    // MARK: - Helper Methods
    
    private func changePassword() {
        isLoading = true
        
        // In a real app, this would call an API to change the password
        
        // Simulate a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            isSuccess = true
            
            // Dismiss after showing success message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }
}

struct ProfileRow: View {
    let key: String
    let value: String
    
    var body: some View {
        HStack {
            Text(key)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            UserProfileView(user: User(
                id: "U12345",
                firstName: "John",
                lastName: "Doe",
                email: "john.doe@example.com",
                phone: "+1234567890",
                role: .customer,
                isActive: true,
                createdAt: Date(),
                lastLogin: Date().addingTimeInterval(-86400)
            ))
        }
    }
} 