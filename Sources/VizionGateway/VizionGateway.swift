import Foundation
import SwiftUI

public final class VizionGateway {
    /// Shared instance of the VizionGateway SDK
    public static let shared = VizionGateway()
    
    /// Current SDK version
    public static let version = "1.0.0"
    
    /// Environment for the SDK
    public enum Environment {
        case sandbox
        case production
    }
    
    /// Configuration for the SDK
    public struct Configuration {
        let apiKey: String
        let merchantId: String
        let environment: Environment
        
        public init(apiKey: String, merchantId: String, environment: Environment = .sandbox) {
            self.apiKey = apiKey
            self.merchantId = merchantId
            self.environment = environment
        }
    }
    
    private var configuration: Configuration?
    
    private init() {}
    
    /// Configure the SDK with your credentials
    /// - Parameter config: SDK configuration
    public static func configure(_ config: Configuration) {
        shared.configuration = config
    }
    
    /// Get the payment manager instance
    public var paymentManager: PaymentManager {
        guard let config = configuration else {
            fatalError("VizionGateway SDK not configured. Call VizionGateway.configure() first.")
        }
        return PaymentManager.shared
    }
    
    /// Check if the SDK is properly configured
    public var isConfigured: Bool {
        configuration != nil
    }
    
    /// Get the base URL for API requests based on environment
    var baseURL: URL {
        guard let config = configuration else {
            fatalError("VizionGateway SDK not configured. Call VizionGateway.configure() first.")
        }
        
        switch config.environment {
        case .sandbox:
            return URL(string: "https://sandbox-api.viziongateway.com")!
        case .production:
            return URL(string: "https://api.viziongateway.com")!
        }
    }
    
    /// Get the API key
    var apiKey: String {
        guard let config = configuration else {
            fatalError("VizionGateway SDK not configured. Call VizionGateway.configure() first.")
        }
        return config.apiKey
    }
    
    /// Get the merchant ID
    var merchantId: String {
        guard let config = configuration else {
            fatalError("VizionGateway SDK not configured. Call VizionGateway.configure() first.")
        }
        return config.merchantId
    }
} 