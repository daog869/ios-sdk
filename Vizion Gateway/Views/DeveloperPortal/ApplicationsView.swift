import SwiftUI
import FirebaseFirestore

struct ApplicationsView: View {
    @State private var applications: [ApplicationModel] = []
    @State private var isLoading = false
    @State private var showingCreateApp = false
    @State private var showingAppDetails = false
    @State private var selectedApp: ApplicationModel?
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var searchText = ""
    
    private let db = Firestore.firestore()
    
    var filteredApplications: [ApplicationModel] {
        if searchText.isEmpty {
            return applications
        } else {
            return applications.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if isLoading && applications.isEmpty {
                    ProgressView("Loading applications...")
                        .progressViewStyle(.circular)
                } else if applications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 60))
                            .foregroundColor(.blue.opacity(0.7))
                        
                        Text("No Applications")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Register your first application to start integrating with Vizion Gateway")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            showingCreateApp = true
                        } label: {
                            Text("Register Application")
                                .padding()
                                .frame(maxWidth: 280)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(filteredApplications) { app in
                            Button {
                                selectedApp = app
                                showingAppDetails = true
                            } label: {
                                ApplicationRow(application: app)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete(perform: deleteApplications)
                    }
                    .searchable(text: $searchText, prompt: "Search applications")
                    .refreshable {
                        await loadApplications()
                    }
                }
            }
            .navigationTitle("Applications")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateApp = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateApp) {
                AppRegistrationView()
                    .onDisappear {
                        Task {
                            await loadApplications()
                        }
                    }
            }
            .sheet(isPresented: $showingAppDetails) {
                if let app = selectedApp {
                    ApplicationDetailView(application: app)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .task {
                await loadApplications()
            }
        }
    }
    
    private func loadApplications() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("applications")
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            var loadedApps: [ApplicationModel] = []
            
            for document in snapshot.documents {
                let data = document.data()
                
                guard let name = data["name"] as? String,
                      let description = data["description"] as? String,
                      let typeString = data["type"] as? String,
                      let type = AppType(rawValue: typeString),
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                    continue
                }
                
                let webhooks = (data["webhooks"] as? [String])?.compactMap { WebhookEventType(rawValue: $0) } ?? []
                let clientId = data["clientId"] as? String ?? "client_\(document.documentID.prefix(16))"
                let clientSecret = data["clientSecret"] as? String ?? "••••••••••••••••"
                let bundleId = data["bundleId"] as? String
                let url = data["url"] as? String
                let redirectURIs = data["redirectURIs"] as? [String] ?? []
                let webhookURL = data["webhookURL"] as? String
                let webhookSecret = data["webhookSecret"] as? String
                let webhookEnvironment = AppEnvironment(rawValue: data["webhookEnvironment"] as? String ?? "production") ?? .production
                
                let app = ApplicationModel(
                    id: document.documentID,
                    name: name,
                    description: description,
                    type: type,
                    createdAt: createdAt,
                    clientId: clientId,
                    clientSecret: clientSecret,
                    webhooks: Set(webhooks),
                    bundleId: bundleId,
                    url: url,
                    redirectURIs: redirectURIs,
                    webhookURL: webhookURL,
                    webhookSecret: webhookSecret,
                    webhookEnvironment: webhookEnvironment
                )
                
                loadedApps.append(app)
            }
            
            await MainActor.run {
                self.applications = loadedApps
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load applications: \(error.localizedDescription)"
                self.showingError = true
            }
        }
    }
    
    private func deleteApplications(at offsets: IndexSet) {
        let appsToDelete = offsets.map { filteredApplications[$0] }
        
        Task {
            do {
                for app in appsToDelete {
                    try await db.collection("applications").document(app.id).delete()
                }
                
                await MainActor.run {
                    self.applications.removeAll { app in
                        appsToDelete.contains { $0.id == app.id }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to delete application: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
}

struct ApplicationRow: View {
    let application: ApplicationModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: application.type.iconName)
                    .foregroundColor(.blue)
                
                Text(application.name)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            Text(application.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(application.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Text("\(application.webhooks.count) webhook\(application.webhooks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
                
                Text(application.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ApplicationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let application: ApplicationModel
    @State private var showingSecret = false
    @State private var showCopyMessage = false
    @State private var copyMessage = ""
    @State private var showingWebhookConfig = false
    @State private var showingWebhookSecret = false
    @State private var enabledWebhooks: Set<WebhookEventType>
    
    init(application: ApplicationModel) {
        self.application = application
        _enabledWebhooks = State(initialValue: application.webhooks)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(application.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            // App type badge
                            Text(application.type.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                        
                        Text(application.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        // Creation details
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Created on \(application.createdAt.formatted(date: .long, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Application Credentials") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Client ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(application.clientId)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = application.clientId
                                copyMessage = "Client ID copied to clipboard"
                                showCopyMessage = true
                            }) {
                                Image(systemName: "doc.on.doc")
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Client Secret")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            if showingSecret {
                                Text(application.clientSecret)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            } else {
                                Text("••••••••••••••••••••••••••")
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showingSecret.toggle()
                            }) {
                                Image(systemName: showingSecret ? "eye.slash" : "eye")
                            }
                            
                            Button(action: {
                                UIPasteboard.general.string = application.clientSecret
                                copyMessage = "Client secret copied to clipboard"
                                showCopyMessage = true
                            }) {
                                Image(systemName: "doc.on.doc")
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                if application.type == .mobileApp, let bundleId = application.bundleId {
                    Section("Mobile App Details") {
                        LabeledContent("Bundle ID", value: bundleId)
                    }
                }
                
                if application.type == .website || application.type == .webApp, let url = application.url {
                    Section("Web Details") {
                        LabeledContent("Website URL", value: url)
                    }
                }
                
                if !application.redirectURIs.isEmpty {
                    Section("Redirect URIs") {
                        ForEach(application.redirectURIs, id: \.self) { uri in
                            Text(uri)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                
                Section("Webhooks") {
                    if application.webhooks.isEmpty {
                        VStack(alignment: .center, spacing: 16) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No webhooks configured")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button {
                                showingWebhookConfig = true
                            } label: {
                                Text("Configure Webhooks")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(application.webhooks).sorted(by: { $0.displayName < $1.displayName }), id: \.self) { webhook in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(webhook.displayName)
                                        .font(.subheadline)
                                    
                                    Text(webhook.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Webhook URL")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text(application.webhookURL ?? "Not configured")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(application.webhookURL == nil ? .secondary : .primary)
                                    
                                    Spacer()
                                    
                                    if application.webhookURL != nil {
                                        Button {
                                            UIPasteboard.general.string = application.webhookURL
                                            copyMessage = "Webhook URL copied to clipboard"
                                            showCopyMessage = true
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                        }
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Webhook Secret")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    if showingWebhookSecret {
                                        Text(application.webhookSecret ?? "Not configured")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(application.webhookSecret == nil ? .secondary : .primary)
                                    } else {
                                        Text(application.webhookSecret != nil ? String(repeating: "•", count: 32) : "Not configured")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(application.webhookSecret == nil ? .secondary : .primary)
                                    }
                                    
                                    Spacer()
                                    
                                    if application.webhookSecret != nil {
                                        Button {
                                            showingWebhookSecret.toggle()
                                        } label: {
                                            Image(systemName: showingWebhookSecret ? "eye.slash" : "eye")
                                        }
                                        
                                        Button {
                                            UIPasteboard.general.string = application.webhookSecret
                                            copyMessage = "Webhook secret copied to clipboard"
                                            showCopyMessage = true
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                        }
                                    }
                                }
                            }
                            
                            Button {
                                showingWebhookConfig = true
                            } label: {
                                Text("Update Webhook Configuration")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Section("Implementation Example") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("API Request with Authentication")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("curl https://api.viziongw.com/v1/payments \\")
                            + Text("\n  -H \"Authorization: Bearer \(application.clientId):\(application.clientSecret)\" \\")
                            + Text("\n  -H \"Content-Type: application/json\" \\")
                            + Text("\n  -d '{\"amount\": 100.00, \"currency\": \"XCD\", ...}'")
                        
                        Button("Copy Example") {
                            let example = """
                            curl https://api.viziongw.com/v1/payments \\
                              -H "Authorization: Bearer \(application.clientId):\(application.clientSecret)" \\
                              -H "Content-Type: application/json" \\
                              -d '{"amount": 100.00, "currency": "XCD", ...}'
                            """
                            UIPasteboard.general.string = example
                            copyMessage = "Example code copied to clipboard"
                            showCopyMessage = true
                        }
                        .padding(.top, 8)
                    }
                    .font(.system(.body, design: .monospaced))
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Application Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if showCopyMessage {
                    VStack {
                        Spacer()
                        Text(copyMessage)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 4)
                            .padding(.bottom, 32)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCopyMessage = false
                                }
                            }
                    }
                }
            }
            .sheet(isPresented: $showingWebhookConfig) {
                WebhookConfigurationView(
                    applicationId: application.id,
                    enabledWebhooks: $enabledWebhooks,
                    currentURL: application.webhookURL,
                    currentSecret: application.webhookSecret,
                    currentEnvironment: application.webhookEnvironment
                )
                    .onDisappear {
                        // Only update if webhooks have changed
                        if enabledWebhooks != application.webhooks {
                            Task {
                                await updateWebhooks()
                            }
                        }
                    }
            }
        }
    }
    
    private func updateWebhooks() async {
        do {
            try await Firestore.firestore().collection("applications").document(application.id).updateData([
                "webhooks": Array(enabledWebhooks).map { $0.rawValue }
            ])
        } catch {
            print("Error updating webhooks: \(error.localizedDescription)")
        }
    }
}

// MARK: - Model

struct ApplicationModel: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let type: AppType
    let createdAt: Date
    let clientId: String
    let clientSecret: String
    let webhooks: Set<WebhookEventType>
    let bundleId: String?
    let url: String?
    let redirectURIs: [String]
    let webhookURL: String?
    let webhookSecret: String?
    let webhookEnvironment: AppEnvironment
    
    static func == (lhs: ApplicationModel, rhs: ApplicationModel) -> Bool {
        return lhs.id == rhs.id
    }
}

// Add icon name to AppType
extension AppType {
    var iconName: String {
        switch self {
        case .mobileApp:
            return "iphone"
        case .webApp:
            return "desktopcomputer"
        case .website:
            return "globe"
        case .serverApp:
            return "server.rack"
        }
    }
}

#Preview {
    ApplicationsView()
} 