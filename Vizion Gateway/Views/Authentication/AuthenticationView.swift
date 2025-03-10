import SwiftUI
import SwiftData

@MainActor
struct AuthenticationView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingRegistration: Bool
    @State private var showingTwoFactor = false
    @State private var isLoggingIn = false
    @State private var email = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(isRegistering: Bool = false) {
        _showingRegistration = State(initialValue: isRegistering)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("VIZION Gateway")
                            .font(.system(size: geometry.size.width > 500 ? 48 : 34, weight: .bold))
                        
                        Text(showingRegistration ? "Create your account" : "Welcome back")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 48)
                    
                    VStack(spacing: 16) {
                        Button {
                            showingTwoFactor = true
                        } label: {
                            Text("Continue to 2FA")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: geometry.size.width > 500 ? 400 : .infinity)
                                .frame(height: 56)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        
                        if AuthenticationManager.shared.isBiometricAvailable {
                            Button {
                                showingTwoFactor = true
                            } label: {
                                Label("Use Face ID", systemImage: "faceid")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: geometry.size.width > 500 ? 400 : .infinity)
                                    .frame(height: 56)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    HStack {
                        Text(showingRegistration ? "Already have an account?" : "Don't have an account?")
                            .foregroundStyle(.secondary)
                        
                        Button(showingRegistration ? "Sign In" : "Create Account") {
                            showingRegistration.toggle()
                        }
                        .foregroundStyle(.blue)
                    }
                    .padding(.bottom, 32)
                }
                .frame(minHeight: geometry.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
        }
        .sheet(isPresented: $showingRegistration) {
            NavigationView {
                RegistrationView()
            }
        }
        .sheet(isPresented: $showingTwoFactor) {
            NavigationView {
                TwoFactorView(email: "test@example.com")
            }
        }
    }
}

@MainActor
struct RegistrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var phoneNumber = ""
    @State private var address = ""
    @State private var isRegistering = false
    @State private var showingTerms = false
    @State private var acceptedTerms = false
    
    var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        !phoneNumber.isEmpty &&
        !address.isEmpty &&
        password == confirmPassword &&
        acceptedTerms
    }
    
    var body: some View {
        Form {
            Section("Personal Information") {
                TextField("First Name", text: $firstName)
                    .textContentType(.givenName)
                
                TextField("Last Name", text: $lastName)
                    .textContentType(.familyName)
                
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                
                TextField("Phone Number", text: $phoneNumber)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                
                TextField("Address", text: $address)
                    .textContentType(.fullStreetAddress)
            }
            
            Section("Security") {
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)
            }
            
            Section {
                Toggle(isOn: $acceptedTerms) {
                    Text("I accept the terms and conditions")
                }
                
                Button("View Terms") {
                    showingTerms = true
                }
                .foregroundStyle(.blue)
            }
            
            Section {
                Button(action: register) {
                    if isRegistering {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Create Account")
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(!isFormValid || isRegistering)
            }
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingTerms) {
            NavigationView {
                TermsView()
            }
        }
    }
    
    private func register() {
        isRegistering = true
        
        Task { @MainActor in
            if await AuthenticationManager.shared.register(
                firstName: firstName,
                lastName: lastName,
                email: email,
                password: password,
                phoneNumber: phoneNumber,
                address: address,
                role: .customer,
                modelContext: modelContext
            ) {
                dismiss()
            } else {
                // Show error alert
                // This would be implemented in a real app
            }
            isRegistering = false
        }
    }
}

struct TwoFactorView: View {
    let email: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Two-Factor Authentication")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Enter the verification code sent to \(email)")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                isLoggedIn = true
                // This ensures we go back to root and show main app
                dismiss()
            } label: {
                Text("Enter App")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .padding()
    }
}

struct MainAppView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    
    var body: some View {
        TabView {
            AuthDashboardPreview()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
            
            TransactionsView()
                .tabItem {
                    Label("Transactions", systemImage: "arrow.left.arrow.right")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .ignoresSafeArea()
    }
}

struct AuthDashboardPreview: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Preview indicator
                VStack(spacing: 10) {
                    Image(systemName: "eye")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                    
                    Text("Preview Mode")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Sign in to see your real transaction data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 50)
                
                // Quick Actions
                VStack(spacing: 8) {
                    Text("Quick Actions")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        Spacer()
                        QuickActionButton(title: "Send", icon: "arrow.up.circle.fill")
                        Spacer()
                        QuickActionButton(title: "Request", icon: "arrow.down.circle.fill")
                        Spacer()
                        QuickActionButton(title: "QR", icon: "qrcode")
                        Spacer()
                    }
                    .padding()
                }
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .ignoresSafeArea()
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.blue)
                .frame(width: 50, height: 50)
                .background(.blue.opacity(0.1))
                .clipShape(Circle())
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TransactionsView: View {
    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView()
                } else if transactions.isEmpty {
                    VStack {
                        Image(systemName: "arrow.left.arrow.right.circle")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Text("No transactions yet")
                            .font(.headline)
                        
                        Text("Your completed transactions will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding()
                } else {
                    List {
                        ForEach(transactions) { transaction in
                            NavigationLink(destination: AuthTransactionDetailView(transaction: transaction)) {
                                TransactionListRow(transaction: transaction)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadTransactions()
            }
            .refreshable {
                await loadTransactions()
            }
        }
        .navigationViewStyle(.stack)
        .ignoresSafeArea()
    }
    
    private func loadTransactions() async {
        isLoading = true
        
        do {
            transactions = try await FirebaseManager.shared.getTransactions(limit: 20)
        } catch {
            self.error = error
            print("Error loading transactions: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}

struct TransactionListRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            // Transaction type icon
            Image(systemName: transaction.type == .payment ? "arrow.right.circle.fill" : "arrow.left.circle.fill")
                .font(.title2)
                .foregroundStyle(transaction.type == .payment ? .blue : .green)
            
            VStack(alignment: .leading) {
                Text(transaction.transactionDescription ?? transaction.type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(formatDate(transaction.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Amount
            Text(formatAmount(transaction.amount, transaction.currency))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatAmount(_ amount: Decimal, _ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let sign = transaction.type == .payment ? "-" : "+"
        return sign + (formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00")
    }
}

// Rename TransactionDetailView to avoid redeclaration
struct AuthTransactionDetailView: View {
    let transaction: Transaction
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Transaction Header
                VStack(alignment: .center, spacing: 8) {
                    Text(formatAmount(transaction.amount, transaction.currency))
                        .font(.system(size: 34, weight: .bold))
                        .padding(.top)
                    
                    Text(transaction.status.rawValue)
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor(transaction.status).opacity(0.1))
                        .foregroundColor(statusColor(transaction.status))
                        .clipShape(Capsule())
                    
                    Text(formatDetailDate(transaction.timestamp))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // Transaction Details - Fix the GroupBox label argument
                GroupBox {
                    VStack(spacing: 15) {
                        TransactionDetailRow(label: "Transaction ID", value: transaction.id)
                        TransactionDetailRow(label: "Type", value: transaction.type.rawValue)
                        TransactionDetailRow(label: "Payment Method", value: transaction.paymentMethod.rawValue)
                        if let description = transaction.transactionDescription {
                            TransactionDetailRow(label: "Description", value: description)
                        }
                        TransactionDetailRow(label: "Merchant", value: transaction.merchantName)
                    }
                    .padding(.vertical, 8)
                } label: {
                    Label("Transaction Details", systemImage: "info.circle")
                        .font(.headline)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatAmount(_ amount: Decimal, _ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let sign = transaction.type == .payment ? "-" : "+"
        return sign + (formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00")
    }
    
    private func formatDetailDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func statusColor(_ status: TransactionStatus) -> Color {
        switch status {
        case .completed:
            return .green
        case .pending, .processing:
            return .orange
        case .failed, .disputed, .cancelled:
            return .red
        case .refunded:
            return .blue
        }
    }
}

// Rename DetailRow to avoid redeclaration
struct TransactionDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

struct SettingsView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    NavigationLink {
                        ProfileSettingsView()
                    } label: {
                        Label("Profile", systemImage: "person.circle")
                    }
                    
                    NavigationLink {
                        SecuritySettingsView()
                    } label: {
                        Label("Security", systemImage: "lock")
                    }
                    
                    NavigationLink {
                        NotificationsSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                }
                
                Section("Support") {
                    NavigationLink {
                        HelpCenterView()
                    } label: {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }
                    
                    Button {
                        // Open chat support
                    } label: {
                        Label("Contact Us", systemImage: "message")
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        isLoggedIn = false
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .ignoresSafeArea()
    }
}

struct TermsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("Terms and Conditions")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Last updated: January 2025")
                        .foregroundStyle(.secondary)
                    
                    Text("1. Acceptance of Terms")
                        .font(.headline)
                    
                    Text("By accessing and using VIZION Gateway, you accept and agree to be bound by the terms and provision of this agreement.")
                    
                    Text("2. Description of Service")
                        .font(.headline)
                    
                    Text("VIZION Gateway provides payment processing services in St. Kitts and Nevis, allowing users to send and receive payments in Eastern Caribbean Dollars (XCD).")
                    
                    Text("3. Privacy Policy")
                        .font(.headline)
                    
                    Text("Your privacy is important to us. Our Privacy Policy explains how we collect, use, and protect your personal information.")
                    
                    Text("4. User Obligations")
                        .font(.headline)
                    
                    Text("Users must provide accurate information and maintain the security of their account credentials.")
                }
                
                Group {
                    Text("5. Fees and Charges")
                        .font(.headline)
                    
                    Text("Transaction fees:\n- Local: 0.5%\n- Regional: 1%\n- International: 1.5%\n- Minimum fee: $1 XCD")
                    
                    Text("6. Compliance")
                        .font(.headline)
                    
                    Text("Users must comply with all applicable laws and regulations, including ECCB guidelines and AML requirements.")
                }
            }
            .padding()
        }
        .navigationTitle("Terms and Conditions")
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

struct ProfileSettingsView: View {
    @State private var firstName = "John"
    @State private var lastName = "Doe"
    @State private var email = "john.doe@example.com"
    @State private var phone = "+1 (869) 123-4567"
    @State private var address = "123 Main St, Basseterre"
    
    var body: some View {
        List {
            Section {
                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                TextField("Phone", text: $phone)
                TextField("Address", text: $address)
            }
            
            Section {
                Button("Save Changes") {
                    // Save changes
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.blue)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SecuritySettingsView: View {
    @State private var isBiometricsEnabled = true
    @State private var isNotificationsEnabled = true
    @State private var showingChangePassword = false
    
    var body: some View {
        List {
            Section {
                Toggle("Face ID / Touch ID", isOn: $isBiometricsEnabled)
                Toggle("Push Notifications", isOn: $isNotificationsEnabled)
            }
            
            Section {
                Button("Change Password") {
                    showingChangePassword = true
                }
                .foregroundStyle(.blue)
                
                Button("Two-Factor Authentication") {
                    // Configure 2FA
                }
                .foregroundStyle(.blue)
            }
            
            Section {
                NavigationLink {
                    DeviceManagementView()
                } label: {
                    Label("Device Management", systemImage: "iphone.and.arrow.forward")
                }
                
                NavigationLink {
                    LoginHistoryView()
                } label: {
                    Label("Login History", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingChangePassword) {
            NavigationView {
                SecurityChangePasswordView()
            }
        }
    }
}

struct DeviceManagementView: View {
    var body: some View {
        List {
            Section {
                DeviceRow(name: "iPhone 15 Pro", isCurrentDevice: true)
                DeviceRow(name: "MacBook Pro", isCurrentDevice: false)
                DeviceRow(name: "iPad Air", isCurrentDevice: false)
            }
        }
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DeviceRow: View {
    let name: String
    let isCurrentDevice: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                if isCurrentDevice {
                    Text("Current Device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if !isCurrentDevice {
                Button("Remove") {
                    // Remove device
                }
                .foregroundStyle(.red)
            }
        }
    }
}

struct LoginHistoryView: View {
    var body: some View {
        List {
            ForEach(1...10, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Login from iPhone")
                        .font(.subheadline)
                    Text("Today, 2:30 PM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Basseterre, St. Kitts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Login History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SecurityChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        List {
            Section {
                SecureField("Current Password", text: $currentPassword)
                SecureField("New Password", text: $newPassword)
                SecureField("Confirm Password", text: $confirmPassword)
            }
            
            Section {
                Button("Update Password") {
                    // Update password
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .disabled(newPassword.isEmpty || newPassword != confirmPassword)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

struct NotificationsSettingsView: View {
    @State private var pushEnabled = true
    @State private var emailEnabled = true
    @State private var transactionAlerts = true
    @State private var securityAlerts = true
    @State private var marketingAlerts = false
    
    var body: some View {
        List {
            Section("Channels") {
                Toggle("Push Notifications", isOn: $pushEnabled)
                Toggle("Email Notifications", isOn: $emailEnabled)
            }
            
            Section("Alert Types") {
                Toggle("Transaction Alerts", isOn: $transactionAlerts)
                Toggle("Security Alerts", isOn: $securityAlerts)
                Toggle("Marketing & Promotions", isOn: $marketingAlerts)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpCenterView: View {
    var body: some View {
        List {
            Section("Common Issues") {
                NavigationLink("Transaction Failed") {
                    FAQDetailView(title: "Transaction Failed", content: "If your transaction failed, please check the following:\n\n1. Sufficient funds\n2. Daily limit\n3. Network connection\n4. Card status")
                }
                
                NavigationLink("Account Access") {
                    FAQDetailView(title: "Account Access", content: "Having trouble accessing your account? Here are some steps to resolve common issues...")
                }
                
                NavigationLink("Payment Methods") {
                    FAQDetailView(title: "Payment Methods", content: "Learn about the different payment methods available...")
                }
            }
            
            Section("Contact Support") {
                Button {
                    // Open chat
                } label: {
                    Label("Live Chat", systemImage: "message")
                }
                
                Button {
                    // Call support
                } label: {
                    Label("Call Support", systemImage: "phone")
                }
                
                Button {
                    // Email support
                } label: {
                    Label("Email Support", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQDetailView: View {
    let title: String
    let content: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(content)
                    .padding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AuthenticationView()
        .modelContainer(for: MerchantUser.self, inMemory: true)
} 