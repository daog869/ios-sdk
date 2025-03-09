import SwiftUI
import SwiftData

struct UserManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    
    @State private var searchText = ""
    @State private var showingAddUser = false
    @State private var showingFilters = false
    @State private var selectedUserRole: UserRole?
    @State private var showInactive = false
    @State private var isRefreshing = false
    
    var filteredUsers: [User] {
        users.filter { user in
            // Apply search filter
            let searchMatch = searchText.isEmpty ||
                user.firstName.localizedCaseInsensitiveContains(searchText) ||
                user.lastName.localizedCaseInsensitiveContains(searchText) ||
                user.email.localizedCaseInsensitiveContains(searchText)
            
            // Apply role filter
            let roleMatch = selectedUserRole == nil || user.role == selectedUserRole
            
            // Apply active filter
            let activeMatch = showInactive || user.isActive
            
            return searchMatch && roleMatch && activeMatch
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filter bar
                HStack(spacing: 16) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        
                        TextField("Search users", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                    
                    // Filter Button
                    Button(action: {
                        withAnimation {
                            showingFilters.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease.circle\(selectedUserRole != nil || showInactive ? ".fill" : "")")
                            Text("Filter")
                        }
                        .padding(8)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // Add User Button
                    Button(action: {
                        showingAddUser = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add User")
                        }
                        .padding(8)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .cornerRadius(8)
                    }
                }
                .padding()
                
                // Filters
                if showingFilters {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Filters")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Reset") {
                                selectedUserRole = nil
                                showInactive = false
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Role")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Picker("Role", selection: $selectedUserRole) {
                                Text("All Roles").tag(nil as UserRole?)
                                ForEach(UserRole.allCases, id: \.self) { role in
                                    Text(role.rawValue).tag(role as UserRole?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Toggle("Show inactive users", isOn: $showInactive)
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                }
                
                // User List
                List {
                    ForEach(filteredUsers) { user in
                        NavigationLink(destination: UserDetailView(user: user)) {
                        UserRow(user: user)
                            }
                    }
                    .onDelete { indexSet in
                        deleteUsers(at: indexSet)
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if users.isEmpty {
                        ContentUnavailableView(
                            "No Users",
                            systemImage: "person.slash",
                            description: Text("Add users to manage access to the payment gateway")
                        )
                    } else if filteredUsers.isEmpty {
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "magnifyingglass",
                            description: Text("Try changing your search or filters")
                        )
                    }
                }
            }
            .navigationTitle("User Management")
            .refreshable {
                await refreshData()
            }
            .sheet(isPresented: $showingAddUser) {
                AddUserView()
            }
        }
    }
    
    // MARK: - Methods
    
    private func deleteUsers(at offsets: IndexSet) {
        for index in offsets {
            let user = filteredUsers[index]
            modelContext.delete(user)
        }
    }
    
    private func refreshData() async {
        isRefreshing = true
        // Simulate data refresh delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
        
        // When Firebase is integrated, this would refresh user data from the cloud
    }
}

// MARK: - Supporting Views

struct UserRow: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 16) {
            // User avatar
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Text(initials)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(user.firstName) \(user.lastName)")
                    .font(.headline)
            
            Text(user.email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
                Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(user.role.rawValue)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(roleColor.opacity(0.1))
                    .foregroundStyle(roleColor)
                    .cornerRadius(4)
                
                if !user.isActive {
                    Text("Inactive")
            .font(.caption)
            .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var initials: String {
        let firstInitial = user.firstName.first?.uppercased() ?? ""
        let lastInitial = user.lastName.first?.uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
    
    private var roleColor: Color {
        switch user.role {
        case .admin:
            return .red
        case .merchant:
            return .purple
        case .customer:
            return .green
        case .bank:
            return .indigo
        case .manager:
            return .orange
        case .analyst:
            return .blue
        case .viewer:
            return .gray
        }
    }
}

struct UserDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let user: User
    @State private var isEditing = false
    @State private var editedFirstName: String
    @State private var editedLastName: String
    @State private var editedEmail: String
    @State private var editedPhone: String
    @State private var editedRole: UserRole
    @State private var editedStatus: Bool
    
    // History of user actions (would come from Firebase in production)
    @State private var userActivities: [UserActivity] = []
    
    // Active sessions (would come from Firebase in production)
    @State private var activeSessions: [UserSession] = []
    
    init(user: User) {
        self.user = user
        _editedFirstName = State(initialValue: user.firstName)
        _editedLastName = State(initialValue: user.lastName)
        _editedEmail = State(initialValue: user.email)
        _editedPhone = State(initialValue: user.phone ?? "")
        _editedRole = State(initialValue: user.role)
        _editedStatus = State(initialValue: user.isActive)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // User Profile Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("User Profile")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(isEditing ? "Save" : "Edit") {
                            if isEditing {
                                saveChanges()
                            }
                            isEditing.toggle()
                        }
                        .fontWeight(isEditing ? .bold : .regular)
                    }
                    
                    Divider()
                    
                    VStack(spacing: 16) {
                        // User info form
                        Group {
                            if isEditing {
                                TextField("First Name", text: $editedFirstName)
                                    .textFieldStyle(.roundedBorder)
                                
                                TextField("Last Name", text: $editedLastName)
                                    .textFieldStyle(.roundedBorder)
                                
                                TextField("Email", text: $editedEmail)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                
                                TextField("Phone", text: $editedPhone)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.phonePad)
                                
                                Picker("Role", selection: $editedRole) {
                                    ForEach(UserRole.allCases, id: \.self) { role in
                                        Text(role.rawValue).tag(role)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                Toggle("Active", isOn: $editedStatus)
                            } else {
                                LabeledContent("Name", value: "\(user.firstName) \(user.lastName)")
                                
                LabeledContent("Email", value: user.email)
                                
                                if let phone = user.phone {
                                    LabeledContent("Phone", value: phone)
            }
            
                                LabeledContent("Role", value: user.role.rawValue)
                                
                                LabeledContent("Status", value: user.isActive ? "Active" : "Inactive")
                                
                                LabeledContent("Created", value: user.createdAt.formatted(date: .abbreviated, time: .shortened))
                                
                                if let lastLogin = user.lastLogin {
                                    LabeledContent("Last Login", value: lastLogin.formatted(date: .abbreviated, time: .shortened))
                }
            }
                        }
                        
                        // Reset Password Button
                        Button(action: resetPassword) {
                            Text("Reset Password")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Active Sessions Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Active Sessions")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Sign Out All") {
                            signOutAllSessions()
                }
                        .foregroundStyle(.red)
                    }
                    
                    Divider()
                    
                    if activeSessions.isEmpty {
                        Text("No active sessions")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(activeSessions) { session in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.deviceName)
                                        .font(.subheadline)
                                    
                                    Text(session.lastActive.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                    }
                                
                                Spacer()
                                
                                Button("Sign Out") {
                                    signOutSession(session)
                                }
                                .font(.caption)
                                .foregroundStyle(.red)
                            }
                            .padding(.vertical, 8)
                            
                            if session.id != activeSessions.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // User Activity Log
                VStack(alignment: .leading, spacing: 16) {
                    Text("Activity Log")
                        .font(.headline)
                    
                    Divider()
                    
                    if userActivities.isEmpty {
                        Text("No activity recorded")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(userActivities) { activity in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(activity.activityType.rawValue)
                                        .font(.subheadline)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(activityColor(activity.activityType).opacity(0.1))
                                        .foregroundStyle(activityColor(activity.activityType))
                                        .cornerRadius(4)
                                    
                                    Spacer()
                                    
                                    Text(activity.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text(activity.description)
                                    .font(.body)
                                    .padding(.top, 4)
                            }
                            .padding(.vertical, 8)
                            
                            if activity.id != userActivities.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            .padding()
            }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("User Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadUserData()
        }
    }
    
    // MARK: - Methods
    
    private func loadUserData() {
        // Simulate loading user sessions and activity
        // This would come from Firebase in production
        
        activeSessions = [
            UserSession(id: UUID().uuidString, deviceName: "iPhone 15 Pro", ipAddress: "192.168.1.1", lastActive: Date()),
            UserSession(id: UUID().uuidString, deviceName: "MacBook Pro", ipAddress: "192.168.1.2", lastActive: Date().addingTimeInterval(-3600))
        ]
        
        userActivities = [
            UserActivity(id: UUID().uuidString, activityType: .login, description: "Logged in from iPhone", timestamp: Date()),
            UserActivity(id: UUID().uuidString, activityType: .transaction, description: "Processed payment for Merchant XYZ", timestamp: Date().addingTimeInterval(-7200)),
            UserActivity(id: UUID().uuidString, activityType: .apiKey, description: "Generated new API key", timestamp: Date().addingTimeInterval(-86400)),
            UserActivity(id: UUID().uuidString, activityType: .settings, description: "Updated account settings", timestamp: Date().addingTimeInterval(-172800))
        ]
    }
    
    private func saveChanges() {
        // In production, this would update Firebase
        user.firstName = editedFirstName
        user.lastName = editedLastName
        user.email = editedEmail
        user.phone = editedPhone.isEmpty ? nil : editedPhone
        user.role = editedRole
        user.isActive = editedStatus
    }
    
    private func resetPassword() {
        // In production, this would trigger a Firebase password reset email
        // For now, just add it to the activity log
        let newActivity = UserActivity(
            id: UUID().uuidString,
            activityType: .security,
            description: "Password reset initiated",
            timestamp: Date()
        )
        
        userActivities.insert(newActivity, at: 0)
    }
    
    private func signOutSession(_ session: UserSession) {
        // Remove the session
        if let index = activeSessions.firstIndex(where: { $0.id == session.id }) {
            activeSessions.remove(at: index)
            }
        
        // Add activity log
        let newActivity = UserActivity(
            id: UUID().uuidString,
            activityType: .security,
            description: "Signed out from \(session.deviceName)",
            timestamp: Date()
        )
        
        userActivities.insert(newActivity, at: 0)
    }
    
    private func signOutAllSessions() {
        activeSessions.removeAll()
        
        // Add activity log
        let newActivity = UserActivity(
            id: UUID().uuidString,
            activityType: .security,
            description: "Signed out from all devices",
            timestamp: Date()
        )
        
        userActivities.insert(newActivity, at: 0)
    }
    
    private func activityColor(_ type: ActivityType) -> Color {
        switch type {
        case .login:
            return .green
        case .logout:
            return .blue
        case .transaction:
            return .purple
        case .settings:
            return .gray
        case .apiKey:
            return .orange
        case .security:
            return .red
        }
    }
}

struct AddUserView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var role: UserRole = .viewer
    @State private var sendInvite = true
    @State private var isSaving = false
    
    var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && isValidEmail(email)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("User Details") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone (optional)", text: $phone)
                        .keyboardType(.phonePad)
                    }
                    
                Section("Access Level") {
                    Picker("Role", selection: $role) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    Toggle("Send invitation email", isOn: $sendInvite)
                }
                
                Section {
                        Button {
                        addUser()
                        } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Add User")
                                .frame(maxWidth: .infinity)
                                }
                            }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .navigationTitle("Add User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addUser() {
        isSaving = true
        
        // Create a new user
        let newUser = User(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone.isEmpty ? nil : phone,
            role: role,
            createdAt: Date()
        )
        
        // In production, this would save to Firebase
        // For now, just add to local SwiftData
        modelContext.insert(newUser)
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSaving = false
            dismiss()
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

// MARK: - Data Models

struct UserSession: Identifiable {
    let id: String
    let deviceName: String
    let ipAddress: String
    let lastActive: Date
}

struct UserActivity: Identifiable {
    let id: String
    let activityType: ActivityType
    let description: String
    let timestamp: Date
}

enum ActivityType: String {
    case login = "Login"
    case logout = "Logout"
    case transaction = "Transaction"
    case settings = "Settings"
    case apiKey = "API Key"
    case security = "Security"
}

#Preview {
        UserManagementView()
        .modelContainer(for: [User.self], inMemory: true)
} 