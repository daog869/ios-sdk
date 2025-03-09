import SwiftUI
import SwiftData

struct UserManagementView: View {
    @Query(sort: \User.createdAt, order: .reverse) private var users: [User]
    @State private var searchText = ""
    @State private var selectedUser: User?
    @State private var kycFilter: KYCStatus?
    @State private var showingFilters = false
    
    var filteredUsers: [User] {
        users.filter { user in
            let matchesSearch = searchText.isEmpty ||
                user.firstName.localizedCaseInsensitiveContains(searchText) ||
                user.lastName.localizedCaseInsensitiveContains(searchText) ||
                user.email.localizedCaseInsensitiveContains(searchText)
            
            let matchesKYC = kycFilter == nil || user.kycStatus == kycFilter
            
            return matchesSearch && matchesKYC
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List {
                    ForEach(filteredUsers) { user in
                        UserRow(user: user)
                            .onTapGesture {
                                selectedUser = user
                            }
                    }
                }
                .listStyle(.plain)
            }
            .ignoresSafeArea(edges: .horizontal)
            .searchable(text: $searchText, prompt: "Search users...")
            .navigationTitle("User Management")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingFilters.toggle()
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(item: $selectedUser) { user in
                NavigationView {
                    UserDetailView(user: user)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingFilters) {
                UserFilterView(kycFilter: $kycFilter)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct UserRow: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(user.firstName) \(user.lastName)")
                    .font(.headline)
                Spacer()
                KYCBadge(status: user.kycStatus)
            }
            
            Text(user.email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                Label(user.phoneNumber, systemImage: "phone")
                Spacer()
                Text(user.createdAt, format: .dateTime)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct KYCBadge: View {
    let status: KYCStatus
    
    var color: Color {
        switch status {
        case .verified: return .green
        case .pending: return .orange
        case .submitted: return .blue
        case .rejected: return .red
        }
    }
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct UserDetailView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingActionSheet = false
    @State private var isEditingUser = false
    
    var body: some View {
        List {
            Section("Personal Information") {
                LabeledContent("First Name", value: user.firstName)
                LabeledContent("Last Name", value: user.lastName)
                LabeledContent("Email", value: user.email)
                LabeledContent("Phone", value: user.phoneNumber)
                LabeledContent("Address", value: user.address)
            }
            
            Section("Account Status") {
                LabeledContent("KYC Status", value: user.kycStatus.rawValue)
                LabeledContent("Verified", value: user.isVerified ? "Yes" : "No")
                LabeledContent("Created", value: user.createdAt, format: .dateTime)
                if let lastLogin = user.lastLoginAt {
                    LabeledContent("Last Login", value: lastLogin, format: .dateTime)
                }
            }
            
            Section("Transactions") {
                ForEach(user.transactions.prefix(5)) { transaction in
                    TransactionRow(transaction: transaction)
                }
                
                if user.transactions.count > 5 {
                    NavigationLink("View All Transactions") {
                        UserTransactionsView(user: user)
                    }
                }
            }
            
            Section {
                Button("Update KYC Status") {
                    showingActionSheet = true
                }
                .foregroundStyle(.blue)
                
                Button("Edit User") {
                    isEditingUser = true
                }
                .foregroundStyle(.orange)
            }
        }
        .navigationTitle("User Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .confirmationDialog(
            "Update KYC Status",
            isPresented: $showingActionSheet,
            titleVisibility: .visible
        ) {
            ForEach(KYCStatus.allCases, id: \.self) { status in
                Button(status.rawValue.capitalized) {
                    updateKYCStatus(status)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $isEditingUser) {
            NavigationView {
                EditUserView(user: user)
            }
            .presentationDetents([.medium])
        }
    }
    
    private func updateKYCStatus(_ newStatus: KYCStatus) {
        user.kycStatus = newStatus
        if newStatus == .verified {
            user.isVerified = true
        }
        try? modelContext.save()
    }
}

struct EditUserView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var lastName: String
    @State private var email: String
    @State private var phoneNumber: String
    @State private var address: String
    
    init(user: User) {
        self.user = user
        _firstName = State(initialValue: user.firstName)
        _lastName = State(initialValue: user.lastName)
        _email = State(initialValue: user.email)
        _phoneNumber = State(initialValue: user.phoneNumber)
        _address = State(initialValue: user.address)
    }
    
    var body: some View {
        Form {
            Section("Personal Information") {
                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                TextField("Phone", text: $phoneNumber)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                TextField("Address", text: $address)
                    .textContentType(.fullStreetAddress)
            }
            
            Section {
                Button("Save Changes") {
                    saveChanges()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Edit User")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
    
    private func saveChanges() {
        user.firstName = firstName
        user.lastName = lastName
        user.email = email
        user.phoneNumber = phoneNumber
        user.address = address
        try? user.modelContext?.save()
        dismiss()
    }
}

struct UserTransactionsView: View {
    let user: User
    
    var body: some View {
        List(user.transactions) { transaction in
            TransactionRow(transaction: transaction)
        }
        .navigationTitle("User Transactions")
    }
}

struct UserFilterView: View {
    @Binding var kycFilter: KYCStatus?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button("All Users") {
                        kycFilter = nil
                        dismiss()
                    }
                    
                    ForEach(KYCStatus.allCases, id: \.self) { status in
                        Button {
                            kycFilter = status
                            dismiss()
                        } label: {
                            HStack {
                                Text(status.rawValue.capitalized)
                                Spacer()
                                if status == kycFilter {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        UserManagementView()
    }
    .modelContainer(for: [User.self, Transaction.self], inMemory: true)
} 