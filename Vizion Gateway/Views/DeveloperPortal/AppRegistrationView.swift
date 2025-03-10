import SwiftUI
import FirebaseFirestore
import Vizion_Gateway  // Add this import for WebhookEventType

struct AppRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appName = ""
    @State private var appDescription = ""
    @State private var appType = AppType.mobileApp
    @State private var appURL = ""
    @State private var bundleID = ""
    @State private var redirectURIs = ""
    @State private var enabledWebhooks: Set<WebhookEventType> = []
    @State private var isLoading = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var selectedAPIKey = ""
    @State private var apiKeys: [APIKey] = []
    @State private var showingWebhookConfig = false
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            Form {
                // App Details
                Section("Basic Information") {
                    TextField("App Name", text: $appName)
                        .disableAutocorrection(true)
                    
                    Picker("App Type", selection: $appType) {
                        ForEach(AppType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    ZStack(alignment: .topLeading) {
                        if appDescription.isEmpty {
                            Text("App Description")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $appDescription)
                            .frame(minHeight: 100)
                    }
                }
                
                // App-specific details based on type
                Section("Application Details") {
                    if appType == .website || appType == .webApp {
                        TextField("Website URL", text: $appURL)
                            .keyboardType(.URL)
                            .disableAutocorrection(true)
                    }
                    
                    if appType == .mobileApp {
                        TextField("Bundle ID", text: $bundleID)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                    }
                    
                    TextField("Redirect URIs (comma-separated)", text: $redirectURIs)
                        .disableAutocorrection(true)
                }
                
                // API Keys
                Section("API Keys") {
                    Picker("API Key", selection: $selectedAPIKey) {
                        Text("Select API Key").tag("")
                        ForEach(apiKeys, id: \.key) { key in
                            Text("\(key.name) (\(key.key.prefix(8))...)").tag(key.key)
                        }
                    }
                    
                    if selectedAPIKey.isEmpty {
                        Button("Load API Keys") {
                            Task {
                                await loadAPIKeys()
                            }
                        }
                    }
                }
                
                // Webhook Configuration
                Section {
                    Button {
                        showingWebhookConfig = true
                    } label: {
                        HStack {
                            Text("Configure Webhooks")
                            Spacer()
                            Text("\(enabledWebhooks.count) enabled")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Webhooks")
                } footer: {
                    Text("Webhooks allow your application to receive real-time notifications about events in your Vizion Gateway account.")
                }
                
                // Register Button
                Section {
                    Button {
                        registerApp()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Register Application")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading || !isFormValid)
                }
            }
            .navigationTitle("Register Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(successMessage ?? "")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showingWebhookConfig) {
                WebhookConfigurationView(
                    applicationId: "",  // This will be updated when we have the application ID
                    enabledWebhooks: $enabledWebhooks,
                    currentURL: nil,
                    currentSecret: nil,
                    currentEnvironment: .sandbox
                )
            }
            .onAppear {
                Task {
                    await loadAPIKeys()
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        guard !appName.isEmpty, !appDescription.isEmpty, !selectedAPIKey.isEmpty else {
            return false
        }
        
        if appType == .website || appType == .webApp {
            guard !appURL.isEmpty else { return false }
        }
        
        if appType == .mobileApp {
            guard !bundleID.isEmpty else { return false }
        }
        
        return true
    }
    
    private func loadAPIKeys() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("apiKeys")
                .whereField("active", isEqualTo: true)
                .getDocuments()
            
            var keys: [APIKey] = []
            for document in snapshot.documents {
                let data = document.data()
                guard let key = data["key"] as? String,
                      let name = data["name"] as? String,
                      let merchantId = data["merchantId"] as? String,
                      let active = data["active"] as? Bool,
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                    continue
                }
                
                // Get scopes from the data
                var scopes: Set<APIScope> = []
                if let scopeStrings = data["scopes"] as? [String] {
                    for scopeString in scopeStrings {
                        if let scope = APIScope(rawValue: scopeString) {
                            scopes.insert(scope)
                        }
                    }
                }
                
                let apiKey = APIKey(
                    id: document.documentID,
                    name: name,
                    key: key,
                    createdAt: createdAt,
                    environment: AppEnvironment(rawValue: UserDefaults.standard.string(forKey: "environment") ?? "sandbox") ?? .sandbox,
                    lastUsed: nil,
                    scopes: scopes,
                    active: active,
                    merchantId: merchantId,
                    expiresAt: nil,
                    ipRestrictions: nil,
                    metadata: nil
                )
                keys.append(apiKey)
            }
            
            await MainActor.run {
                self.apiKeys = keys
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load API keys: \(error.localizedDescription)"
                self.showingError = true
            }
        }
    }
    
    private func registerApp() {
        isLoading = true
        
        // Create app data
        var appData: [String: Any] = [
            "name": appName,
            "description": appDescription,
            "type": appType.rawValue,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "apiKey": selectedAPIKey,
            "webhooks": enabledWebhooks.map { $0.rawValue },
            "webhookURL": "",  // Will be updated when webhooks are configured
            "webhookSecret": "",  // Will be updated when webhooks are configured
            "webhookEnvironment": AppEnvironment.sandbox.rawValue,
            "status": "active"
        ]
        
        // Add type-specific details
        if appType == .website || appType == .webApp {
            appData["url"] = appURL
        }
        
        if appType == .mobileApp {
            appData["bundleId"] = bundleID
        }
        
        // Add redirect URIs if provided
        if !redirectURIs.isEmpty {
            let uris = redirectURIs.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
            appData["redirectURIs"] = uris
        }
        
        // Generate client credentials
        let clientId = "client_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let clientSecret = "secret_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        
        appData["clientId"] = clientId
        appData["clientSecret"] = clientSecret
        
        // Save to Firestore
        Task {
            do {
                let docRef = try await db.collection("applications").addDocument(data: appData)
                
                await MainActor.run {
                    successMessage = """
                        Application registered successfully!
                        Client ID: \(clientId)
                        Client Secret: \(clientSecret)
                        
                        Please save these credentials securely as the client secret will not be shown again.
                        """
                    showingSuccess = true
                    isLoading = false
                    
                    // Dismiss after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to register application: \(error.localizedDescription)"
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum AppType: String, CaseIterable {
    case mobileApp = "mobile_app"
    case webApp = "web_app"
    case website = "website"
    case serverApp = "server_app"
    
    var displayName: String {
        switch self {
        case .mobileApp:
            return "Mobile App"
        case .webApp:
            return "Web Application"
        case .website:
            return "Website"
        case .serverApp:
            return "Server-Side Application"
        }
    }
}

#Preview {
    AppRegistrationView()
} 