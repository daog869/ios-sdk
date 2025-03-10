import SwiftUI
import SwiftData
import PassKit

// MARK: - Models

struct WebhookEndpoint: Identifiable {
    let id: String
    let url: String
    let events: [String]
    let isActive: Bool
    let createdAt: Date
}

struct APILogEntry: Identifiable {
    let id: String
    let timestamp: Date
    let method: String
    let path: String
    let statusCode: Int
    let duration: TimeInterval
    let environment: String
}

// MARK: - Main View

struct DeveloperPortalView: View {
    @State private var selectedTab = "API Keys"
    
    var body: some View {
        NavigationView {
            List {
                // Environment Indicator
                if let environment = UserDefaults.standard.string(forKey: "environment"),
                   environment == AppEnvironment.sandbox.rawValue {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading) {
                                Text("Sandbox Testing Mode")
                                    .font(.headline)
                                Text("Test environment for external API integrations and webhooks. Perfect for development and testing.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color.orange.opacity(0.1))
                    }
                }
                
                // API Keys Section
                Section {
                    NavigationLink {
                        APIKeysView()
                    } label: {
                        Label("API Keys", systemImage: "key.fill")
                    }
                }
                
                // Webhooks Section
                Section {
                    NavigationLink {
                        WebhookConfigurationView()
                    } label: {
                        Label("Webhooks", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                
                // Documentation Section
                Section(header: Text("Documentation")) {
                    NavigationLink {
                        APIDocumentationView()
                    } label: {
                        Label("API Reference", systemImage: "doc.text.fill")
                    }
                    
                    NavigationLink {
                        SDKGuideView()
                    } label: {
                        Label("SDK Guides", systemImage: "book.fill")
                    }
                    
                    NavigationLink {
                        WebhookGuideView()
                    } label: {
                        Label("Webhook Events", systemImage: "bell.fill")
                    }
                }
                
                // Testing Tools Section
                Section(header: Text("Testing Tools")) {
                    NavigationLink {
                        TestTransactionComponent()
                    } label: {
                        Label("Test Transactions", systemImage: "creditcard.fill")
                    }
                    
                    NavigationLink {
                        WebhookTesterComponent()
                    } label: {
                        Label("Webhook Tester", systemImage: "arrow.triangle.pull")
                    }
                    
                    NavigationLink {
                        APILogsView()
                    } label: {
                        Label("API Logs", systemImage: "text.alignleft")
                    }
                }
                
                // Environment Section
                Section {
                    Picker("Environment", selection: .init(
                        get: {
                            UserDefaults.standard.string(forKey: "environment") ?? AppEnvironment.sandbox.rawValue
                        },
                        set: { newValue in
                            UserDefaults.standard.set(newValue, forKey: "environment")
                            NotificationCenter.default.post(name: .environmentChanged, object: nil)
                        }
                    )) {
                        ForEach(AppEnvironment.allCases, id: \.self) { env in
                            Text(env.displayName).tag(env.rawValue)
                        }
                    }
                } header: {
                    Text("Environment")
                } footer: {
                    Text("Switching environments will affect all API operations. Use Sandbox for testing and Production for live transactions.")
                }
            }
            .navigationTitle("Developer Portal")
        }
    }
}

// MARK: - Documentation Views

struct SDKGuideView: View {
    var body: some View {
        List {
            Section("Getting Started") {
                NavigationLink("Installation") {
                    MarkdownContentView(fileName: "sdk_installation")
                }
                NavigationLink("Configuration") {
                    MarkdownContentView(fileName: "sdk_configuration")
                }
                NavigationLink("Quick Start") {
                    MarkdownContentView(fileName: "sdk_quickstart")
                }
            }
            
            Section("Integration Guides") {
                NavigationLink("Payment Processing") {
                    MarkdownContentView(fileName: "sdk_payments")
                }
                NavigationLink("Customer Management") {
                    MarkdownContentView(fileName: "sdk_customers")
                }
                NavigationLink("Error Handling") {
                    MarkdownContentView(fileName: "sdk_errors")
                }
            }
        }
        .navigationTitle("SDK Documentation")
    }
}

struct WebhookGuideView: View {
    var body: some View {
        List {
            Section("Overview") {
                NavigationLink("Introduction") {
                    MarkdownContentView(fileName: "webhook_intro")
                }
                NavigationLink("Security") {
                    MarkdownContentView(fileName: "webhook_security")
                }
            }
            
            Section("Event Types") {
                NavigationLink("Payment Events") {
                    MarkdownContentView(fileName: "webhook_payment_events")
                }
                NavigationLink("Customer Events") {
                    MarkdownContentView(fileName: "webhook_customer_events")
                }
                NavigationLink("Dispute Events") {
                    MarkdownContentView(fileName: "webhook_dispute_events")
                }
            }
        }
        .navigationTitle("Webhook Documentation")
    }
}

// Additional Views

struct WebhookConfigurationView: View {
    @State private var webhooks: [WebhookEndpoint] = []
    @State private var showingAddWebhook = false
    
    var body: some View {
        List {
            ForEach(webhooks) { webhook in
                WebhookEndpointRow(webhook: webhook)
            }
        }
        .navigationTitle("Webhooks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddWebhook = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct WebhookEndpointRow: View {
    let webhook: WebhookEndpoint
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(webhook.url)
                    .font(.headline)
                Spacer()
                Text(webhook.isActive ? "Active" : "Inactive")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(webhook.isActive ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .foregroundStyle(webhook.isActive ? .green : .red)
                    .clipShape(Capsule())
            }
            
            Text("Events: \(webhook.events.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("Created: \(webhook.createdAt.formatted())")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct APIDocumentationView: View {
    @State private var content = ""
    
    var body: some View {
        ScrollView {
            if content.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 50)
            } else {
                Text(.init(content))
                    .padding()
            }
        }
        .navigationTitle("API Documentation")
        .task {
            if let url = Bundle.main.url(forResource: "api_reference", withExtension: "md"),
               let markdown = try? String(contentsOf: url) {
                content = markdown
            }
        }
    }
}

struct MarkdownContentView: View {
    let fileName: String
    @State private var content = ""
    
    var body: some View {
        ScrollView {
            Text(content)
                .padding()
        }
        .onAppear {
            // Load markdown content
            content = "Documentation content will be loaded here"
        }
    }
}

// Notification extension for environment changes
extension Notification.Name {
    static let environmentChanged = Notification.Name("environmentChanged")
} 