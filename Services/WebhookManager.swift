import Foundation
import CryptoKit
import SwiftData

@Model
final class WebhookEndpoint: Identifiable {
    var id: String
    var businessId: String
    var url: String
    var events: [WebhookEvent]
    var secret: String
    var isActive: Bool
    var createdAt: Date
    var lastDeliveryAt: Date?
    var failureCount: Int
    var retryCount: Int
    
    init(businessId: String, url: String, events: [WebhookEvent]) {
        self.id = UUID().uuidString
        self.businessId = businessId
        self.url = url
        self.events = events
        self.secret = WebhookManager.generateSecret()
        self.isActive = true
        self.createdAt = Date()
        self.failureCount = 0
        self.retryCount = 0
    }
}

enum WebhookEvent: String, Codable {
    case transactionCreated = "transaction.created"
    case transactionCompleted = "transaction.completed"
    case transactionFailed = "transaction.failed"
    case walletUpdated = "wallet.updated"
    case userCreated = "user.created"
    case userUpdated = "user.updated"
    case withdrawalRequested = "withdrawal.requested"
    case withdrawalCompleted = "withdrawal.completed"
}

class WebhookManager {
    static let shared = WebhookManager()
    private let modelContext: ModelContext
    private let queue = DispatchQueue(label: "com.viziongateway.webhooks", qos: .utility)
    private let retryDelays = [1, 5, 15, 30, 60] // Retry delays in minutes
    
    private init() {
        let container = try! ModelContainer(for: WebhookEndpoint.self)
        self.modelContext = ModelContext(container)
    }
    
    // MARK: - Webhook Management
    
    static func generateSecret() -> String {
        let secretBytes = SymmetricKey(size: .bits256)
        return Data(secretBytes.withUnsafeBytes { Array($0) }).base64EncodedString()
    }
    
    func createEndpoint(
        businessId: String,
        url: String,
        events: [WebhookEvent]
    ) throws -> WebhookEndpoint {
        let endpoint = WebhookEndpoint(businessId: businessId, url: url, events: events)
        modelContext.insert(endpoint)
        try modelContext.save()
        return endpoint
    }
    
    func getEndpoints(for businessId: String) throws -> [WebhookEndpoint] {
        let descriptor = FetchDescriptor<WebhookEndpoint>(
            predicate: #Predicate<WebhookEndpoint> { endpoint in
                endpoint.businessId == businessId && endpoint.isActive
            }
        )
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Webhook Delivery
    
    func deliverWebhook(
        event: WebhookEvent,
        businessId: String,
        payload: [String: Any]
    ) {
        queue.async {
            do {
                let endpoints = try self.getEndpoints(for: businessId)
                    .filter { $0.events.contains(event) }
                
                for endpoint in endpoints {
                    self.sendWebhook(to: endpoint, event: event, payload: payload)
                }
            } catch {
                print("Error delivering webhook: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendWebhook(
        to endpoint: WebhookEndpoint,
        event: WebhookEvent,
        payload: [String: Any],
        retryCount: Int = 0
    ) {
        var webhookPayload = payload
        webhookPayload["event"] = event.rawValue
        webhookPayload["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: webhookPayload) else {
            return
        }
        
        // Create signature
        let signature = generateSignature(for: jsonData, secret: endpoint.secret)
        
        // Create request
        var request = URLRequest(url: URL(string: endpoint.url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sha256=\(signature)", forHTTPHeaderField: "X-Vizion-Signature")
        request.setValue(event.rawValue, forHTTPHeaderField: "X-Vizion-Event")
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                // Success
                endpoint.lastDeliveryAt = Date()
                endpoint.failureCount = 0
                try? self.modelContext.save()
            } else {
                // Failure
                endpoint.failureCount += 1
                try? self.modelContext.save()
                
                // Retry if needed
                if retryCount < self.retryDelays.count {
                    let delay = self.retryDelays[retryCount]
                    DispatchQueue.global().asyncAfter(deadline: .now() + .minutes(Double(delay))) {
                        self.sendWebhook(
                            to: endpoint,
                            event: event,
                            payload: payload,
                            retryCount: retryCount + 1
                        )
                    }
                }
            }
        }
        
        task.resume()
    }
    
    private func generateSignature(for data: Data, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(signature).base64EncodedString()
    }
    
    // MARK: - Webhook Verification
    
    func verifySignature(
        payload: Data,
        signature: String,
        secret: String
    ) -> Bool {
        let computedSignature = generateSignature(for: payload, secret: secret)
        return signature == "sha256=\(computedSignature)"
    }
}

// MARK: - Webhook Response

struct WebhookResponse: Codable {
    let success: Bool
    let message: String?
    let data: [String: AnyCodable]?
    
    struct AnyCodable: Codable {
        let value: Any
        
        init(_ value: Any) {
            self.value = value
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                value = string
            } else if let int = try? container.decode(Int.self) {
                value = int
            } else if let double = try? container.decode(Double.self) {
                value = double
            } else if let bool = try? container.decode(Bool.self) {
                value = bool
            } else if let array = try? container.decode([AnyCodable].self) {
                value = array.map { $0.value }
            } else if let dictionary = try? container.decode([String: AnyCodable].self) {
                value = dictionary.mapValues { $0.value }
            } else {
                value = NSNull()
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch value {
            case let string as String:
                try container.encode(string)
            case let int as Int:
                try container.encode(int)
            case let double as Double:
                try container.encode(double)
            case let bool as Bool:
                try container.encode(bool)
            case let array as [Any]:
                try container.encode(array.map { AnyCodable($0) })
            case let dictionary as [String: Any]:
                try container.encode(dictionary.mapValues { AnyCodable($0) })
            default:
                try container.encodeNil()
            }
        }
    }
} 