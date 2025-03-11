import Foundation
import CryptoKit

/// Handles webhook management and validation
public final class WebhookManager {
    /// Shared instance for singleton access
    public static let shared = WebhookManager()
    
    private let networkManager: NetworkManager
    private let logger: Logger
    
    private init() {
        self.networkManager = NetworkManager()
        self.logger = Logger.shared
    }
    
    /// Registers a webhook URL for receiving notifications
    /// - Parameters:
    ///   - url: The URL that will receive webhook notifications
    ///   - events: Array of event types to subscribe to
    ///   - description: Optional description of the webhook
    public func registerWebhook(
        url: URL,
        events: [WebhookEvent],
        description: String? = nil
    ) async throws -> WebhookRegistration {
        logger.info("Registering webhook for URL: \(url.absoluteString)")
        
        guard ConfigurationManager.shared.isConfigured else {
            logger.error("SDK not configured")
            throw NetworkError.unauthorized
        }
        
        let request = WebhookRegistrationRequest(
            url: url.absoluteString,
            events: events.map { $0.rawValue },
            description: description
        )
        
        do {
            let registration: WebhookRegistration = try await networkManager.request(
                endpoint: "webhooks",
                method: "POST",
                body: request
            )
            
            logger.info("Successfully registered webhook: \(registration.id)")
            return registration
        } catch {
            logger.error("Failed to register webhook: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Updates an existing webhook registration
    /// - Parameters:
    ///   - id: The ID of the webhook registration to update
    ///   - url: Optional new URL
    ///   - events: Optional new array of event types
    ///   - description: Optional new description
    public func updateWebhook(
        id: String,
        url: URL? = nil,
        events: [WebhookEvent]? = nil,
        description: String? = nil
    ) async throws -> WebhookRegistration {
        logger.info("Updating webhook: \(id)")
        
        guard ConfigurationManager.shared.isConfigured else {
            logger.error("SDK not configured")
            throw NetworkError.unauthorized
        }
        
        let request = WebhookUpdateRequest(
            url: url?.absoluteString,
            events: events?.map { $0.rawValue },
            description: description
        )
        
        do {
            let registration: WebhookRegistration = try await networkManager.request(
                endpoint: "webhooks/\(id)",
                method: "PATCH",
                body: request
            )
            
            logger.info("Successfully updated webhook: \(id)")
            return registration
        } catch {
            logger.error("Failed to update webhook: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Deletes a webhook registration
    /// - Parameter id: The ID of the webhook registration to delete
    public func deleteWebhook(id: String) async throws {
        logger.info("Deleting webhook: \(id)")
        
        guard ConfigurationManager.shared.isConfigured else {
            logger.error("SDK not configured")
            throw NetworkError.unauthorized
        }
        
        do {
            try await networkManager.requestWithoutResponse(
                endpoint: "webhooks/\(id)",
                method: "DELETE"
            )
            
            logger.info("Successfully deleted webhook: \(id)")
        } catch {
            logger.error("Failed to delete webhook: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Lists all registered webhooks
    /// - Returns: Array of webhook registrations
    public func listWebhooks() async throws -> [WebhookRegistration] {
        logger.info("Retrieving webhook registrations")
        
        guard ConfigurationManager.shared.isConfigured else {
            logger.error("SDK not configured")
            throw NetworkError.unauthorized
        }
        
        do {
            let registrations: [WebhookRegistration] = try await networkManager.request(
                endpoint: "webhooks",
                method: "GET"
            )
            
            logger.info("Retrieved \(registrations.count) webhook registrations")
            return registrations
        } catch {
            logger.error("Failed to retrieve webhooks: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Validates a webhook signature
    /// - Parameters:
    ///   - payload: The raw webhook payload
    ///   - signature: The signature from the X-Webhook-Signature header
    ///   - secret: The webhook secret key
    /// - Returns: Whether the signature is valid
    public func validateWebhookSignature(
        payload: Data,
        signature: String,
        secret: String
    ) -> Bool {
        guard let secretData = secret.data(using: .utf8) else {
            logger.error("Invalid webhook secret")
            return false
        }
        
        let key = SymmetricKey(data: secretData)
        let hmac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        let computedSignature = Data(hmac).base64EncodedString()
        
        let isValid = signature == computedSignature
        
        if !isValid {
            logger.warning("Invalid webhook signature")
        }
        
        return isValid
    }
}

/// Events that can trigger webhook notifications
public enum WebhookEvent: String, Codable {
    case paymentSucceeded = "payment.succeeded"
    case paymentFailed = "payment.failed"
    case refundSucceeded = "refund.succeeded"
    case refundFailed = "refund.failed"
    case disputeCreated = "dispute.created"
    case disputeUpdated = "dispute.updated"
    case disputeResolved = "dispute.resolved"
}

/// Represents a webhook registration
public struct WebhookRegistration: Codable {
    public let id: String
    public let url: String
    public let events: [String]
    public let description: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let status: WebhookStatus
    
    private enum CodingKeys: String, CodingKey {
        case id
        case url
        case events
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case status
    }
}

/// Status of a webhook registration
public enum WebhookStatus: String, Codable {
    case active
    case disabled
    case failed
}

// MARK: - Supporting Types

private struct WebhookRegistrationRequest: Encodable {
    let url: String
    let events: [String]
    let description: String?
}

private struct WebhookUpdateRequest: Encodable {
    let url: String?
    let events: [String]?
    let description: String?
} 