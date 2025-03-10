import Foundation
import FirebaseFirestore
import SwiftData

// MARK: - API Scopes
enum APIScope: String, Codable, CaseIterable, Hashable {
    case payments = "payments"           // Process payments and refunds
    case payouts = "payouts"            // Handle payouts to merchants
    case customers = "customers"         // Manage customer data
    case disputes = "disputes"          // Handle disputes and chargebacks
    case webhooks = "webhooks"          // Manage webhook endpoints
    case reports = "reports"            // Access reporting and analytics
    case terminals = "terminals"        // Manage POS terminals
    case settings = "settings"          // Access merchant settings
    
    var description: String {
        switch self {
        case .payments:
            return "Process payments and issue refunds"
        case .payouts:
            return "Manage merchant payouts"
        case .customers:
            return "Create and manage customer data"
        case .disputes:
            return "Handle disputes and chargebacks"
        case .webhooks:
            return "Configure webhook endpoints"
        case .reports:
            return "Access transaction reports and analytics"
        case .terminals:
            return "Manage POS terminals"
        case .settings:
            return "Access and update merchant settings"
        }
    }
}

// MARK: - API Key Model
@Model
final class APIKey: Identifiable, Hashable {
    var id: String
    var name: String
    var key: String
    var createdAt: Date
    var environment: AppEnvironment
    var lastUsed: Date?
    var scopes: Set<APIScope>
    var active: Bool
    var merchantId: String
    var expiresAt: Date?
    var ipRestrictions: [String]?
    var metadata: [String: String]?
    
    init(
        id: String,
        name: String,
        key: String,
        createdAt: Date,
        environment: AppEnvironment,
        lastUsed: Date? = nil,
        scopes: Set<APIScope> = Set(APIScope.allCases),
        active: Bool = true,
        merchantId: String = "",
        expiresAt: Date? = nil,
        ipRestrictions: [String]? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.name = name
        self.key = key
        self.createdAt = createdAt
        self.environment = environment
        self.lastUsed = lastUsed
        self.scopes = scopes
        self.active = active
        self.merchantId = merchantId
        self.expiresAt = expiresAt
        self.ipRestrictions = ipRestrictions
        self.metadata = metadata
    }
    
    var isLive: Bool {
        return environment == .production
    }
    
    // MARK: - Hashable Conformance
    
    static func == (lhs: APIKey, rhs: APIKey) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Firestore Conversion
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "key": key,
            "createdAt": createdAt,
            "environment": environment.rawValue,
            "active": active,
            "merchantId": merchantId,
            "scopes": scopes.map { $0.rawValue }
        ]
        
        if let lastUsed = lastUsed {
            dict["lastUsed"] = lastUsed
        }
        if let expiresAt = expiresAt {
            dict["expiresAt"] = expiresAt
        }
        if let ipRestrictions = ipRestrictions {
            dict["ipRestrictions"] = ipRestrictions
        }
        if let metadata = metadata {
            dict["metadata"] = metadata
        }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any], id: String) -> APIKey? {
        guard let name = dict["name"] as? String,
              let key = dict["key"] as? String,
              let createdAt = (dict["createdAt"] as? Timestamp)?.dateValue(),
              let environmentString = dict["environment"] as? String,
              let environment = AppEnvironment(rawValue: environmentString),
              let merchantId = dict["merchantId"] as? String,
              let active = dict["active"] as? Bool else {
            return nil
        }
        
        let lastUsed = (dict["lastUsed"] as? Timestamp)?.dateValue()
        let expiresAt = (dict["expiresAt"] as? Timestamp)?.dateValue()
        let ipRestrictions = dict["ipRestrictions"] as? [String]
        let metadata = dict["metadata"] as? [String: String]
        
        let scopeStrings = dict["scopes"] as? [String] ?? []
        let scopes = Set(scopeStrings.compactMap { APIScope(rawValue: $0) })
        
        return APIKey(
            id: id,
            name: name,
            key: key,
            createdAt: createdAt,
            environment: environment,
            lastUsed: lastUsed,
            scopes: scopes,
            active: active,
            merchantId: merchantId,
            expiresAt: expiresAt,
            ipRestrictions: ipRestrictions,
            metadata: metadata
        )
    }
} 