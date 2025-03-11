import Foundation
import CryptoKit
import SwiftData

@Model
final class APIToken: Identifiable {
    var id: String
    var businessId: String
    var name: String
    var token: String
    var scopes: [APIScope]
    var isActive: Bool
    var createdAt: Date
    var expiresAt: Date?
    var lastUsedAt: Date?
    var ipRestrictions: [String]?
    var webhookUrl: String?
    
    init(businessId: String, name: String, scopes: [APIScope]) {
        self.id = UUID().uuidString
        self.businessId = businessId
        self.name = name
        self.token = APITokenManager.generateToken()
        self.scopes = scopes
        self.isActive = true
        self.createdAt = Date()
    }
}

enum APIScope: String, Codable {
    case read = "read"
    case write = "write"
    case transactions = "transactions"
    case users = "users"
    case webhooks = "webhooks"
    case reports = "reports"
}

class APITokenManager {
    static let shared = APITokenManager()
    private let modelContext: ModelContext
    
    private init() {
        let container = try! ModelContainer(for: APIToken.self)
        self.modelContext = ModelContext(container)
    }
    
    // MARK: - Token Generation
    
    static func generateToken() -> String {
        let tokenBytes = SymmetricKey(size: .bits256)
        return Data(tokenBytes.withUnsafeBytes { Array($0) })
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    // MARK: - Token Management
    
    func createToken(
        businessId: String,
        name: String,
        scopes: [APIScope],
        ipRestrictions: [String]? = nil,
        webhookUrl: String? = nil,
        expiresAt: Date? = nil
    ) throws -> APIToken {
        let token = APIToken(businessId: businessId, name: name, scopes: scopes)
        token.ipRestrictions = ipRestrictions
        token.webhookUrl = webhookUrl
        token.expiresAt = expiresAt
        
        modelContext.insert(token)
        try modelContext.save()
        
        return token
    }
    
    func validateToken(_ tokenString: String, requiredScopes: [APIScope], ipAddress: String? = nil) throws -> APIToken {
        let descriptor = FetchDescriptor<APIToken>(
            predicate: #Predicate<APIToken> { token in
                token.token == tokenString && token.isActive
            }
        )
        
        guard let token = try modelContext.fetch(descriptor).first else {
            throw APIError.invalidToken
        }
        
        // Check expiration
        if let expiresAt = token.expiresAt, Date() > expiresAt {
            throw APIError.tokenExpired
        }
        
        // Check IP restrictions
        if let restrictions = token.ipRestrictions,
           let ipAddress = ipAddress,
           !restrictions.isEmpty,
           !restrictions.contains(ipAddress) {
            throw APIError.ipNotAllowed
        }
        
        // Check scopes
        let hasRequiredScopes = requiredScopes.allSatisfy { token.scopes.contains($0) }
        if !hasRequiredScopes {
            throw APIError.insufficientScopes
        }
        
        // Update last used timestamp
        token.lastUsedAt = Date()
        try modelContext.save()
        
        return token
    }
    
    func revokeToken(_ token: APIToken) throws {
        token.isActive = false
        try modelContext.save()
    }
    
    func getTokens(for businessId: String) throws -> [APIToken] {
        let descriptor = FetchDescriptor<APIToken>(
            predicate: #Predicate<APIToken> { token in
                token.businessId == businessId && token.isActive
            }
        )
        return try modelContext.fetch(descriptor)
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidToken
    case tokenExpired
    case ipNotAllowed
    case insufficientScopes
    case webhookFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Invalid or inactive API token"
        case .tokenExpired:
            return "API token has expired"
        case .ipNotAllowed:
            return "IP address not allowed"
        case .insufficientScopes:
            return "Token does not have required permissions"
        case .webhookFailed:
            return "Failed to deliver webhook"
        }
    }
} 