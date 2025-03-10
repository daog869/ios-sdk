import SwiftUI
import FirebaseFirestore

struct WebhookConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    let applicationId: String
    @Binding var enabledWebhooks: Set<WebhookEventType>
    @State private var webhookURL: String
    @State private var selectedEnvironment: AppEnvironment
    @State private var showingSecretKey = false
    @State private var webhookSecret: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    private let allWebhookEvents = WebhookEventType.allCases
    private let db = Firestore.firestore()
    
    init(applicationId: String,
         enabledWebhooks: Binding<Set<WebhookEventType>>,
         currentURL: String?,
         currentSecret: String?,
         currentEnvironment: AppEnvironment) {
        self.applicationId = applicationId
        self._enabledWebhooks = enabledWebhooks
        self._webhookURL = State(initialValue: currentURL ?? "")
        self._webhookSecret = State(initialValue: currentSecret ?? UUID().uuidString)
        self._selectedEnvironment = State(initialValue: currentEnvironment)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Webhook URL") {
                    TextField("https://your-domain.com/webhooks", text: $webhookURL)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Picker("Environment", selection: $selectedEnvironment) {
                        ForEach(AppEnvironment.allCases, id: \.self) { env in
                            Text(env.displayName).tag(env)
                        }
                    }
                } header: {
                    Text("Environment")
                } footer: {
                    Text("Select which environment this webhook endpoint will receive events from.")
                }
                
                Section {
                    HStack {
                        if showingSecretKey {
                            Text(webhookSecret)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            Text(String(repeating: "•", count: 32))
                        }
                        
                        Spacer()
                        
                        Button {
                            showingSecretKey.toggle()
                        } label: {
                            Image(systemName: showingSecretKey ? "eye.slash" : "eye")
                        }
                        
                        Button {
                            UIPasteboard.general.string = webhookSecret
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                } header: {
                    Text("Webhook Secret")
                } footer: {
                    Text("Use this secret to verify that events were sent by Vizion Gateway.")
                }
                
                Section {
                    ForEach(allWebhookEvents, id: \.self) { event in
                        Toggle(isOn: Binding(
                            get: { enabledWebhooks.contains(event) },
                            set: { isEnabled in
                                if isEnabled {
                                    enabledWebhooks.insert(event)
                                } else {
                                    enabledWebhooks.remove(event)
                                }
                            }
                        )) {
                            VStack(alignment: .leading) {
                                Text(event.displayName)
                                    .font(.body)
                                Text(event.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Events to Subscribe")
                } footer: {
                    Text("Select which events you want to receive notifications for.")
                }
                
                Section {
                    Button {
                        Task {
                            await saveConfiguration()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save Configuration")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading || !isValid)
                }
            }
            .navigationTitle("Configure Webhooks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    private var isValid: Bool {
        guard !webhookURL.isEmpty else { return false }
        guard URL(string: webhookURL) != nil else { return false }
        guard !enabledWebhooks.isEmpty else { return false }
        return true
    }
    
    private func saveConfiguration() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Validate URL
            guard let _ = URL(string: webhookURL) else {
                throw NSError(domain: "WebhookConfiguration", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid webhook URL"
                ])
            }
            
            // Update Firestore document
            try await db.collection("applications").document(applicationId).updateData([
                "webhookURL": webhookURL,
                "webhookSecret": webhookSecret,
                "webhookEnvironment": selectedEnvironment.rawValue,
                "webhooks": Array(enabledWebhooks).map { $0.rawValue }
            ])
            
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// Preview provider
struct WebhookConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        WebhookConfigurationView(
            applicationId: "preview",
            enabledWebhooks: .constant([]),
            currentURL: nil,
            currentSecret: nil,
            currentEnvironment: .sandbox
        )
    }
} 