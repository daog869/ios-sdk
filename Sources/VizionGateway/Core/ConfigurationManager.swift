import Foundation

/// Manages configuration settings for the VizionGateway SDK
public final class ConfigurationManager {
    /// Shared instance for singleton access
    public static let shared = ConfigurationManager()
    
    /// Environment for the SDK
    public enum Environment {
        case development
        case staging
        case production
        
        var baseURL: URL {
            switch self {
            case .development:
                return URL(string: "https://dev-api.viziongateway.com/v1")!
            case .staging:
                return URL(string: "https://staging-api.viziongateway.com/v1")!
            case .production:
                return URL(string: "https://api.viziongateway.com/v1")!
            }
        }
    }
    
    /// Current environment setting
    private(set) var environment: Environment
    
    /// API key for authentication
    private(set) var apiKey: String?
    
    /// Merchant ID for the current session
    private(set) var merchantId: String?
    
    /// Timeout interval for network requests (in seconds)
    public var timeoutInterval: TimeInterval = 30
    
    /// Flag indicating whether the SDK has been properly configured
    public var isConfigured: Bool {
        return apiKey != nil && merchantId != nil
    }
    
    private init() {
        self.environment = .development
    }
    
    /// Configures the SDK with required credentials and settings
    /// - Parameters:
    ///   - apiKey: The API key for authentication
    ///   - merchantId: The merchant's unique identifier
    ///   - environment: The target environment (default: .development)
    public func configure(
        apiKey: String,
        merchantId: String,
        environment: Environment = .development
    ) {
        self.apiKey = apiKey
        self.merchantId = merchantId
        self.environment = environment
    }
    
    /// Resets the configuration to its default state
    public func reset() {
        self.apiKey = nil
        self.merchantId = nil
        self.environment = .development
        self.timeoutInterval = 30
    }
    
    /// Returns the base URL for the current environment
    public func getBaseURL() -> URL {
        return environment.baseURL
    }
    
    /// Returns the authorization header value for API requests
    public func getAuthorizationHeader() -> String? {
        guard let apiKey = apiKey else { return nil }
        return "Bearer \(apiKey)"
    }
} 