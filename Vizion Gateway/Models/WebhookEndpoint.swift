import Foundation
import FirebaseFirestore

struct WebhookEndpoint: Identifiable, Codable {
    let id: String
    let url: String
    let events: [String]
    let isActive: Bool
    let createdAt: Date
    let merchantId: String
    let environment: AppEnvironment
    let lastAttempt: Date?
    let lastSuccess: Date?
    let failureCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case url
        case events
        case isActive
        case createdAt
        case merchantId
        case environment
        case lastAttempt
        case lastSuccess
        case failureCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        url = try container.decode(String.self, forKey: .url)
        events = try container.decode([String].self, forKey: .events)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        merchantId = try container.decode(String.self, forKey: .merchantId)
        environment = try container.decode(AppEnvironment.self, forKey: .environment)
        lastAttempt = try container.decodeIfPresent(Date.self, forKey: .lastAttempt)
        lastSuccess = try container.decodeIfPresent(Date.self, forKey: .lastSuccess)
        failureCount = try container.decode(Int.self, forKey: .failureCount)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encode(events, forKey: .events)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(merchantId, forKey: .merchantId)
        try container.encode(environment, forKey: .environment)
        try container.encodeIfPresent(lastAttempt, forKey: .lastAttempt)
        try container.encodeIfPresent(lastSuccess, forKey: .lastSuccess)
        try container.encode(failureCount, forKey: .failureCount)
    }
    
    init(
        id: String,
        url: String,
        events: [String],
        isActive: Bool,
        createdAt: Date,
        merchantId: String,
        environment: AppEnvironment,
        lastAttempt: Date? = nil,
        lastSuccess: Date? = nil,
        failureCount: Int = 0
    ) {
        self.id = id
        self.url = url
        self.events = events
        self.isActive = isActive
        self.createdAt = createdAt
        self.merchantId = merchantId
        self.environment = environment
        self.lastAttempt = lastAttempt
        self.lastSuccess = lastSuccess
        self.failureCount = failureCount
    }
    
    static func fromDictionary(_ dict: [String: Any], id: String) -> WebhookEndpoint? {
        guard let url = dict["url"] as? String,
              let events = dict["events"] as? [String],
              let isActive = dict["isActive"] as? Bool,
              let createdAt = (dict["createdAt"] as? Timestamp)?.dateValue(),
              let merchantId = dict["merchantId"] as? String,
              let environmentString = dict["environment"] as? String,
              let environment = AppEnvironment(rawValue: environmentString) else {
            return nil
        }
        
        let lastAttempt = (dict["lastAttempt"] as? Timestamp)?.dateValue()
        let lastSuccess = (dict["lastSuccess"] as? Timestamp)?.dateValue()
        let failureCount = dict["failureCount"] as? Int ?? 0
        
        return WebhookEndpoint(
            id: id,
            url: url,
            events: events,
            isActive: isActive,
            createdAt: createdAt,
            merchantId: merchantId,
            environment: environment,
            lastAttempt: lastAttempt,
            lastSuccess: lastSuccess,
            failureCount: failureCount
        )
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "url": url,
            "events": events,
            "isActive": isActive,
            "createdAt": createdAt,
            "merchantId": merchantId,
            "environment": environment.rawValue,
            "failureCount": failureCount
        ]
        
        if let lastAttempt = lastAttempt {
            dict["lastAttempt"] = lastAttempt
        }
        if let lastSuccess = lastSuccess {
            dict["lastSuccess"] = lastSuccess
        }
        
        return dict
    }
} 