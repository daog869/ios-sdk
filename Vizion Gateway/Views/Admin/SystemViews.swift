import SwiftUI
import SwiftData
import FirebaseFirestore

struct APIKeysView: View {
    @StateObject private var viewModel = APIKeysViewModel()
    @State private var showingAddKey = false
    @State private var showingKeyReveal = false
    @State private var selectedEnvironment: AppEnvironment = .sandbox
    
    var body: some View {
        List {
            // Environment Selector
            Section {
                Picker("Environment", selection: $selectedEnvironment) {
                    ForEach(AppEnvironment.allCases, id: \.self) { env in
                        Text(env.displayName)
                            .tag(env)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // API Keys List
            Section {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else if let keys = viewModel.apiKeys[selectedEnvironment], !keys.isEmpty {
                    ForEach(keys) { key in
                        APIKeyRow(key: key, showingKeyReveal: showingKeyReveal) {
                            viewModel.revokeKey(key)
                        }
                    }
                } else {
                    Text("No API keys found for \(selectedEnvironment.displayName)")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("API Keys")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(showingKeyReveal ? "Hide Keys" : "Show Keys") {
                    showingKeyReveal.toggle()
                }
                
                Button {
                    showingAddKey = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddKey) {
            NavigationView {
                AddAPIKeyView(environment: selectedEnvironment) { name, scopes, expiresAt, ipRestrictions, metadata in
                    Task {
                        await viewModel.generateKey(
                            name: name,
                            environment: selectedEnvironment,
                            scopes: scopes,
                            expiresAt: expiresAt,
                            ipRestrictions: ipRestrictions,
                            metadata: metadata
                        )
                        showingAddKey = false
                    }
                }
            }
            .presentationDetents([.large])
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .task {
            await viewModel.loadKeys()
        }
    }
}

struct APIKeyRow: View {
    let key: APIKey
    let showingKeyReveal: Bool
    let onRevoke: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Key Info
            HStack {
                VStack(alignment: .leading) {
                    Text(key.name)
                        .font(.headline)
                    Text(showingKeyReveal ? key.key : maskApiKey(key.key))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Status indicators
                HStack(spacing: 4) {
                    // Live/Test indicator
                    Text(key.isLive ? "Live" : "Test")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(key.isLive ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .foregroundStyle(key.isLive ? .green : .orange)
                        .clipShape(Capsule())
                    
                    // Active/Revoked indicator
                    Text(key.active ? "Active" : "Revoked")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(key.active ? Color.blue.opacity(0.1) : Color.red.opacity(0.1))
                        .foregroundStyle(key.active ? .blue : .red)
                        .clipShape(Capsule())
                }
            }
            
            // Scopes
            VStack(alignment: .leading, spacing: 4) {
                Text("Scopes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TagsView(tags: Array(key.scopes)) { scope in
                    Text(scope.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            // Restrictions & Expiry
            if key.ipRestrictions?.isEmpty == false || key.expiresAt != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let ips = key.ipRestrictions, !ips.isEmpty {
                        Text("IP Restrictions: \(ips.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let expiresAt = key.expiresAt {
                        Text("Expires: \(expiresAt.formatted())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = key.key
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                
                if key.active {
                    Button(role: .destructive) {
                        onRevoke()
                    } label: {
                        Label("Revoke", systemImage: "xmark.circle")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                Text("Created: \(key.createdAt.formatted(.dateTime.month().day().year()))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func maskApiKey(_ key: String) -> String {
        guard key.count > 8 else { return key }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        let maskedPart = String(repeating: "•", count: 8)
        return prefix + maskedPart + suffix
    }
}

struct AddAPIKeyView: View {
    let environment: AppEnvironment
    let onSubmit: (String, Set<APIScope>, Date?, [String]?, [String: String]?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedScopes = Set<APIScope>()
    @State private var expiresAt: Date?
    @State private var ipRestrictions = ""
    @State private var metadataKey = ""
    @State private var metadataValue = ""
    @State private var metadata: [String: String] = [:]
    
    var body: some View {
        Form {
            Section {
                TextField("Key Name", text: $name)
                    .textContentType(.name)
                    .autocorrectionDisabled()
            } header: {
                Text("Key Details")
            } footer: {
                Text("This name will help you identify the key's purpose")
            }
            
            Section {
                ForEach(APIScope.allCases, id: \.self) { scope in
                    Toggle(isOn: Binding(
                        get: { selectedScopes.contains(scope) },
                        set: { isSelected in
                            if isSelected {
                                selectedScopes.insert(scope)
                            } else {
                                selectedScopes.remove(scope)
                            }
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text(scope.rawValue.capitalized)
                                .font(.subheadline)
                            Text(scope.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Button("Select All") {
                    selectedScopes = Set(APIScope.allCases)
                }
                .disabled(selectedScopes.count == APIScope.allCases.count)
            } header: {
                Text("Scopes")
            }
            
            Section {
                Toggle("Set Expiration", isOn: Binding(
                    get: { expiresAt != nil },
                    set: { if $0 { expiresAt = Date().addingTimeInterval(30 * 24 * 3600) } else { expiresAt = nil } }
                ))
                
                if expiresAt != nil {
                    DatePicker("Expires At", selection: Binding(
                        get: { expiresAt ?? Date() },
                        set: { expiresAt = $0 }
                    ), in: Date()...)
                }
                
                TextField("IP Restrictions (comma-separated)", text: $ipRestrictions)
                    .textContentType(.none)
                    .autocorrectionDisabled()
            } header: {
                Text("Security")
            } footer: {
                Text("Restrict API key usage to specific IP addresses")
            }
            
            Section {
                HStack {
                    TextField("Key", text: $metadataKey)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                    
                    TextField("Value", text: $metadataValue)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                    
                    Button {
                        if !metadataKey.isEmpty && !metadataValue.isEmpty {
                            metadata[metadataKey] = metadataValue
                            metadataKey = ""
                            metadataValue = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(metadataKey.isEmpty || metadataValue.isEmpty)
                }
                
                ForEach(Array(metadata.keys), id: \.self) { key in
                    HStack {
                        Text(key)
                            .font(.subheadline)
                        Spacer()
                        Text(metadata[key] ?? "")
                            .foregroundStyle(.secondary)
                        Button {
                            metadata.removeValue(forKey: key)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text("Metadata")
            }
        }
        .navigationTitle("New API Key")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Generate") {
                    let ips = ipRestrictions.isEmpty ? nil :
                        ipRestrictions.components(separatedBy: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                    
                    onSubmit(
                        name,
                        selectedScopes.isEmpty ? Set(APIScope.allCases) : selectedScopes,
                        expiresAt,
                        ips,
                        metadata.isEmpty ? nil : metadata
                    )
                }
                .disabled(name.isEmpty)
            }
        }
    }
}

// Helper view for tag flow layout
struct TagsView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let tags: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    
    init(
        tags: Data,
        spacing: CGFloat = 4,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.tags = tags
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: spacing) {
                ForEach(Array(tags.enumerated()), id: \.element) { _, tag in
                    content(tag)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: 32)
    }
}

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

@MainActor
class APIKeysViewModel: ObservableObject {
    @Published var apiKeys: [AppEnvironment: [APIKey]] = [:]
    @Published var isLoading = false
    @Published var showSuccess = false
    @Published var successMessage: String?
    
    private let db = Firestore.firestore()
    
    func loadKeys() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            var allKeys: [AppEnvironment: [APIKey]] = [:]
            
            // Load sandbox keys
            let sandboxKeys = try await fetchKeys(for: .sandbox)
            allKeys[.sandbox] = sandboxKeys
            
            // Load production keys
            let productionKeys = try await fetchKeys(for: .production)
            allKeys[.production] = productionKeys
            
            apiKeys = allKeys
        } catch {
            print("Error loading API keys: \(error.localizedDescription)")
        }
    }
    
    private func fetchKeys(for environment: AppEnvironment) async throws -> [APIKey] {
        let snapshot = try await db.collection("apiKeys")
            .whereField("environment", isEqualTo: environment.rawValue)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> APIKey? in
            let data = doc.data()
            guard let key = data["key"] as? String,
                  let name = data["name"] as? String,
                  let merchantId = data["merchantId"] as? String,
                  let active = data["active"] as? Bool,
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                return nil
            }
            
            return APIKey(
                id: doc.documentID,
                name: name,
                key: key,
                createdAt: createdAt,
                environment: AppEnvironment(rawValue: data["environment"] as? String ?? "sandbox") ?? .sandbox,
                lastUsed: nil,
                scopes: [],
                active: active,
                merchantId: merchantId,
                expiresAt: nil,
                ipRestrictions: nil,
                metadata: nil
            )
        }
    }
    
    func generateKey(name: String, environment: AppEnvironment, scopes: Set<APIScope>, expiresAt: Date?, ipRestrictions: [String]?, metadata: [String: String]?) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Generate a secure random key with environment prefix
            let keyString = "vz_\(environment == .production ? "live" : "test")_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
            
            // Create API key document
            let ref = db.collection("apiKeys").document()
            let keyData: [String: Any] = [
                "key": keyString,
                "name": name,
                "merchantId": "admin", // Special case for admin-generated keys
                "active": true,
                "createdAt": Timestamp(date: Date()),
                "environment": environment.rawValue,
                "scopes": Array(scopes),
                "expiresAt": expiresAt.map { Timestamp(date: $0) },
                "ipRestrictions": ipRestrictions,
                "metadata": metadata
            ]
            
            try await ref.setData(keyData)
            
            // Refresh the keys list
            await loadKeys()
            
            // Show success message
            successMessage = "API key generated successfully"
            showSuccess = true
        } catch {
            print("Error generating API key: \(error.localizedDescription)")
        }
    }
    
    func revokeKey(_ key: APIKey) {
        Task {
            do {
                try await db.collection("apiKeys").document(key.id).updateData([
                    "active": false
                ])
                
                await loadKeys()
                
                successMessage = "API key revoked successfully"
                showSuccess = true
            } catch {
                print("Error revoking API key: \(error.localizedDescription)")
            }
        }
    }
    
    func showCopiedAlert() {
        successMessage = "API key copied to clipboard"
        showSuccess = true
    }
}

struct AccessLogsView: View {
    @State private var logs = [
        "2025-01-14 14:30:23 - Admin login from 192.168.1.1",
        "2025-01-14 14:29:45 - Settings updated",
        "2025-01-14 14:29:30 - Bank connection modified",
        "2025-01-14 14:29:15 - System startup"
    ]
    
    var body: some View {
        List {
            ForEach(logs, id: \.self) { log in
                Text(log)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .navigationTitle("Access Logs")
    }
}

struct ErrorLogsView: View {
    @State private var errors: [SystemError] = []
    @State private var searchText = ""
    @State private var isAutoRefreshing = true
    @State private var lastRefreshed = Date()
    @State private var selectedSeverity: ErrorSeverity?
    @State private var showingFilters = false
    @State private var dateRange: ClosedRange<Date>?
    
    var filteredErrors: [SystemError] {
        errors.prefix(1000).filter { error in
            var matches = true
            
            if !searchText.isEmpty {
                matches = matches && error.message.localizedCaseInsensitiveContains(searchText)
            }
            
            if let severity = selectedSeverity {
                matches = matches && error.severity == severity
            }
            
            if let range = dateRange {
                matches = matches && range.contains(error.timestamp)
            }
            
            return matches
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Status Bar
            HStack {
                Circle()
                    .fill(isAutoRefreshing ? .green : .secondary)
                    .frame(width: 8, height: 8)
                Text(isAutoRefreshing ? "Live" : "Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Last updated: \(lastRefreshed.formatted(.relative(presentation: .numeric)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
            
            List {
                ForEach(filteredErrors) { error in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(error.timestamp, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(error.severity.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(error.severity.color.opacity(0.2))
                                .foregroundStyle(error.severity.color)
                                .clipShape(Capsule())
                        }
                        Text(error.message)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(error.severity.color)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
        .searchable(text: $searchText, prompt: "Search errors...")
        .navigationTitle("Error Logs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button {
                        isAutoRefreshing.toggle()
                    } label: {
                        Label(isAutoRefreshing ? "Pause" : "Resume", systemImage: isAutoRefreshing ? "pause.fill" : "play.fill")
                    }
                    
                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            ErrorFilterView(
                selectedSeverity: $selectedSeverity,
                dateRange: $dateRange
            )
            .presentationDragIndicator(.visible)
        }
        .task {
            // Auto-refresh every 5 seconds when enabled
            while isAutoRefreshing {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                // In a real app, fetch new errors here
                lastRefreshed = Date()
            }
        }
    }
}

struct ErrorFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSeverity: ErrorSeverity?
    @Binding var dateRange: ClosedRange<Date>?
    @State private var startDate = Date()
    @State private var endDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Error Severity") {
                    Picker("Severity", selection: $selectedSeverity) {
                        Text("Any").tag(nil as ErrorSeverity?)
                        ForEach(ErrorSeverity.allCases, id: \.self) { severity in
                            Text(severity.rawValue).tag(severity as ErrorSeverity?)
                        }
                    }
                }
                
                Section("Date Range") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End Date", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section {
                    Button("Apply Filters") {
                        dateRange = startDate...endDate
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button("Clear Filters") {
                        selectedSeverity = nil
                        dateRange = nil
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Filters")
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

struct SystemError: Identifiable {
    let id = UUID()
    let timestamp: Date
    let severity: ErrorSeverity
    let message: String
}

enum ErrorSeverity: String, CaseIterable {
    case critical = "CRITICAL"
    case error = "ERROR"
    case warning = "WARNING"
    case info = "INFO"
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .error: return .orange
        case .warning: return .yellow
        case .info: return .blue
        }
    }
}

struct SystemStatusView: View {
    @State private var selectedTab = "Status"
    @State private var showingSignOutConfirmation = false
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(["Status", "Performance", "Logs"], id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(tab)
                                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .background(.bar)
            
            Divider()
            
            // Content
            TabView(selection: $selectedTab) {
                SystemOverviewView()
                    .tag("Status")
                
                SystemPerformanceView()
                    .tag("Performance")
                
                SystemLogsView()
                    .tag("Logs")
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("System")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    showingSignOutConfirmation = true
                }) {
                    Text("Sign Out")
                        .foregroundColor(.red)
                }
            }
        }
        .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

struct SystemOverviewView: View {
    @State private var services = [
        "Bank Connection": "Online",
        "API Gateway": "Online",
        "Database": "Online",
        "Webhook Service": "Degraded"
    ]
    
    var body: some View {
        List {
            Section("Services") {
                ForEach(Array(services.keys.sorted()), id: \.self) { service in
                    HStack {
                        Text(service)
                        Spacer()
                        HStack {
                            Circle()
                                .fill(statusColor(services[service] ?? ""))
                                .frame(width: 8, height: 8)
                            Text(services[service] ?? "")
                        }
                        .foregroundStyle(statusColor(services[service] ?? ""))
                    }
                }
            }
            
            Section("System Info") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Last Update", value: "2025-01-14 14:30:23")
                LabeledContent("Environment", value: "Production")
                LabeledContent("Region", value: "St. Kitts")
            }
        }
        .listStyle(.plain)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Online": return .green
        case "Degraded": return .orange
        case "Offline": return .red
        default: return .gray
        }
    }
}

struct SystemPerformanceView: View {
    @State private var cpuUsage = 23.0
    @State private var memoryUsage = 512.0
    @State private var storageUsage = 2.1
    @State private var uptime = "5d 12h 30m"
    
    var body: some View {
        List {
            Section("Resources") {
                VStack(spacing: 16) {
                    UsageGauge(title: "CPU", value: cpuUsage, unit: "%", color: gaugeColor(cpuUsage))
                    UsageGauge(title: "Memory", value: memoryUsage, unit: "MB", color: gaugeColor(memoryUsage/1024*100))
                    UsageGauge(title: "Storage", value: storageUsage, unit: "GB", color: gaugeColor(storageUsage/10*100))
                }
                .padding(.vertical)
            }
            
            Section("System Load") {
                LabeledContent("Uptime", value: uptime)
                LabeledContent("Active Users", value: "12")
                LabeledContent("Requests/min", value: "156")
                LabeledContent("Avg Response", value: "235ms")
            }
        }
        .listStyle(.plain)
    }
    
    private func gaugeColor(_ percentage: Double) -> Color {
        switch percentage {
        case 0..<60: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

struct UsageGauge: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
            
            Gauge(value: value/100) {
                EmptyView()
            }
            .gaugeStyle(.accessoryCircular)
            .tint(color)
            .scaleEffect(1.5)
            
            Text("\(value, specifier: "%.1f")\(unit)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct SystemLogsView: View {
    @State private var selectedLogType = 0
    @State private var searchText = ""
    @State private var isAutoRefreshing = true
    @State private var showingFilters = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Log type selector
            Picker("Log Type", selection: $selectedLogType) {
                Text("API").tag(0)
                Text("Access").tag(1)
                Text("Error").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Status bar
            HStack {
                Circle()
                    .fill(isAutoRefreshing ? .green : .secondary)
                    .frame(width: 8, height: 8)
                Text(isAutoRefreshing ? "Live" : "Paused")
                    .font(.caption)
                Spacer()
                Text("Last updated: \(Date().formatted(.relative(presentation: .named)))")
                    .font(.caption)
            }
            .padding(.horizontal)
            
            // Log content
            TabView(selection: $selectedLogType) {
                APILogsView()
                    .tag(0)
                
                AccessLogsView()
                    .tag(1)
                
                ErrorLogsView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .searchable(text: $searchText, prompt: "Search logs...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button {
                        isAutoRefreshing.toggle()
                    } label: {
                        Label(isAutoRefreshing ? "Pause" : "Resume", systemImage: isAutoRefreshing ? "pause.fill" : "play.fill")
                    }
                    
                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
}

struct SystemSettingsView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Section", selection: $selectedTab) {
                    Text("Status").tag(0)
                    Text("Performance").tag(1)
                    Text("Logs").tag(2)
                    Text("Settings").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                TabView(selection: $selectedTab) {
                    // Status Tab
                    SystemStatusView()
                        .tag(0)
                    
                    // Performance Tab
                    SystemPerformanceView()
                        .tag(1)
                    
                    // Logs Tab
                    SystemLogsView()
                        .tag(2)
                    
                    // Settings Tab
                    List {
                        Section("Processing Settings") {
                            Toggle("Auto-retry failed transactions", isOn: .constant(true))
                            Toggle("Real-time fraud detection", isOn: .constant(true))
                            Toggle("Require 2FA for large transactions", isOn: .constant(true))
                        }
                        
                        Section("Security") {
                            Toggle("IP whitelisting", isOn: .constant(true))
                            Toggle("Rate limiting", isOn: .constant(true))
                            Toggle("Audit logging", isOn: .constant(true))
                        }
                        
                        Section("System") {
                            Toggle("Auto backup", isOn: .constant(true))
                            Toggle("Debug mode", isOn: .constant(false))
                            Toggle("Maintenance mode", isOn: .constant(false))
                        }
                    }
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("System")
        }
        .navigationViewStyle(.stack)
    }
} 
