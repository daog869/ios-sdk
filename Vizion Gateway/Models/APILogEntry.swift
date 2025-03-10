import Foundation
import FirebaseFirestore

struct APILogEntry: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let method: String
    let path: String
    let statusCode: Int
    let duration: TimeInterval
    let merchantId: String
    let environment: AppEnvironment
    let requestBody: String?
    let responseBody: String?
    let errorMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case method
        case path
        case statusCode
        case duration
        case merchantId
        case environment
        case requestBody
        case responseBody
        case errorMessage
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        method = try container.decode(String.self, forKey: .method)
        path = try container.decode(String.self, forKey: .path)
        statusCode = try container.decode(Int.self, forKey: .statusCode)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        merchantId = try container.decode(String.self, forKey: .merchantId)
        environment = try container.decode(AppEnvironment.self, forKey: .environment)
        requestBody = try container.decodeIfPresent(String.self, forKey: .requestBody)
        responseBody = try container.decodeIfPresent(String.self, forKey: .responseBody)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(method, forKey: .method)
        try container.encode(path, forKey: .path)
        try container.encode(statusCode, forKey: .statusCode)
        try container.encode(duration, forKey: .duration)
        try container.encode(merchantId, forKey: .merchantId)
        try container.encode(environment, forKey: .environment)
        try container.encodeIfPresent(requestBody, forKey: .requestBody)
        try container.encodeIfPresent(responseBody, forKey: .responseBody)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
    }
    
    init(
        id: String,
        timestamp: Date,
        method: String,
        path: String,
        statusCode: Int,
        duration: TimeInterval,
        merchantId: String,
        environment: AppEnvironment,
        requestBody: String? = nil,
        responseBody: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.path = path
        self.statusCode = statusCode
        self.duration = duration
        self.merchantId = merchantId
        self.environment = environment
        self.requestBody = requestBody
        self.responseBody = responseBody
        self.errorMessage = errorMessage
    }
    
    static func fromDictionary(_ dict: [String: Any], id: String) -> APILogEntry? {
        guard let timestamp = (dict["timestamp"] as? Timestamp)?.dateValue(),
              let method = dict["method"] as? String,
              let path = dict["path"] as? String,
              let statusCode = dict["statusCode"] as? Int,
              let duration = dict["duration"] as? TimeInterval,
              let merchantId = dict["merchantId"] as? String,
              let environmentString = dict["environment"] as? String,
              let environment = AppEnvironment(rawValue: environmentString) else {
            return nil
        }
        
        return APILogEntry(
            id: id,
            timestamp: timestamp,
            method: method,
            path: path,
            statusCode: statusCode,
            duration: duration,
            merchantId: merchantId,
            environment: environment,
            requestBody: dict["requestBody"] as? String,
            responseBody: dict["responseBody"] as? String,
            errorMessage: dict["errorMessage"] as? String
        )
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "timestamp": timestamp,
            "method": method,
            "path": path,
            "statusCode": statusCode,
            "duration": duration,
            "merchantId": merchantId,
            "environment": environment.rawValue
        ]
        
        if let requestBody = requestBody {
            dict["requestBody"] = requestBody
        }
        if let responseBody = responseBody {
            dict["responseBody"] = responseBody
        }
        if let errorMessage = errorMessage {
            dict["errorMessage"] = errorMessage
        }
        
        return dict
    }
} 