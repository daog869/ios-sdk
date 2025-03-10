import SwiftUI
import FirebaseFirestore
import Vizion_Gateway  // Import the module containing WebhookEndpoint

struct WebhookAdminView: View {
    @State private var webhooks: [WebhookEndpoint] = []
    @State private var selectedWebhook: WebhookEndpoint?
    @State private var showingDetail = false
    @State private var enabledWebhooks: Set<WebhookEventType> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            List {
                if webhooks.isEmpty {
                    Text("No webhooks configured")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(webhooks) { webhook in
                        Button {
                            selectedWebhook = webhook
                            // Convert string events to WebhookEventType Set
                            enabledWebhooks = Set(
                                webhook.events.compactMap { WebhookEventType(rawValue: $0) }
                            )
                            showingDetail = true
                        } label: {
                            WebhookListItem(webhook: webhook)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Webhook Management")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        enabledWebhooks = []
                        selectedWebhook = nil
                        showingDetail = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let webhook = selectedWebhook {
                    WebhookConfigurationView(
                        applicationId: webhook.id,
                        enabledWebhooks: $enabledWebhooks,
                        currentURL: webhook.url,
                        currentSecret: "",  // Secret isn't stored in the WebhookEndpoint model
                        currentEnvironment: webhook.environment
                    )
                } else {
                    // Creating a new webhook
                    WebhookConfigurationView(
                        applicationId: "new_webhook",
                        enabledWebhooks: $enabledWebhooks,
                        currentURL: nil,
                        currentSecret: nil,
                        currentEnvironment: .sandbox
                    )
                }
            }
            .refreshable {
                await loadWebhooks()
            }
            .task {
                await loadWebhooks()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    private func loadWebhooks() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await Firestore.firestore().collection("webhooks")
                .getDocuments()
            
            var loadedWebhooks: [WebhookEndpoint] = []
            
            for document in snapshot.documents {
                let data = document.data()
                
                // Create WebhookEndpoint instance from snapshot data
                guard let url = data["url"] as? String,
                      let isActive = data["isActive"] as? Bool,
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                      let merchantId = data["merchantId"] as? String,
                      let environmentString = data["environment"] as? String,
                      let environment = AppEnvironment(rawValue: environmentString)
                else {
                    continue
                }
                
                let eventStrings = data["events"] as? [String] ?? []
                let lastAttempt = (data["lastAttempt"] as? Timestamp)?.dateValue()
                let lastSuccess = (data["lastSuccess"] as? Timestamp)?.dateValue()
                let failureCount = data["failureCount"] as? Int ?? 0
                
                let webhook = WebhookEndpoint(
                    id: document.documentID,
                    url: url,
                    events: eventStrings,
                    isActive: isActive,
                    createdAt: createdAt,
                    merchantId: merchantId,
                    environment: environment,
                    lastAttempt: lastAttempt,
                    lastSuccess: lastSuccess,
                    failureCount: failureCount
                )
                
                loadedWebhooks.append(webhook)
            }
            
            await MainActor.run {
                self.webhooks = loadedWebhooks
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }
}

struct WebhookListItem: View {
    let webhook: WebhookEndpoint
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(webhook.url)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                // Status badge
                Text(webhook.isActive ? "Active" : "Inactive")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(webhook.isActive ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .foregroundColor(webhook.isActive ? .green : .red)
                    .cornerRadius(4)
            }
            
            Text("Environment: \(webhook.environment.displayName)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Events: \(webhook.events.joined(separator: ", "))")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text("Created: \(webhook.createdAt.formatted())")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WebhookAdminView()
} 