import SwiftUI

struct WebhookTesterComponent: View {
    @StateObject private var apiService = APIService.shared
    @State private var webhookURL = ""
    @State private var selectedEvent = "transaction.created"
    @State private var customPayload = ""
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section {
                TextField("Webhook URL", text: $webhookURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                
                Picker("Event Type", selection: $selectedEvent) {
                    Text("Transaction Created").tag("transaction.created")
                    Text("Transaction Updated").tag("transaction.updated")
                    Text("Refund Created").tag("refund.created")
                }
            }
            
            Section("Custom Payload (Optional)") {
                TextEditor(text: $customPayload)
                    .frame(height: 100)
            }
            
            Section {
                Button {
                    sendTestWebhook()
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Send Test Webhook")
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(webhookURL.isEmpty || isLoading)
            }
        }
        .navigationTitle("Webhook Tester")
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Test webhook sent successfully")
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private func sendTestWebhook() {
        guard let url = URL(string: webhookURL) else {
            errorMessage = "Invalid webhook URL"
            return
        }
        
        var payload: [String: Any]?
        if !customPayload.isEmpty {
            do {
                if let data = customPayload.data(using: .utf8),
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    payload = json
                }
            } catch {
                errorMessage = "Invalid JSON payload"
                return
            }
        }
        
        isLoading = true
        Task {
            do {
                try await apiService.sendTestWebhook(
                    url: url,
                    event: selectedEvent,
                    payload: payload
                )
                await MainActor.run {
                    isLoading = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
} 