import Foundation

/// Handles error reporting and management for the SDK
public final class ErrorHandler {
    /// Shared instance for singleton access
    public static let shared = ErrorHandler()
    
    private let logger: Logger
    private let analytics: Analytics
    
    private init() {
        self.logger = Logger.shared
        self.analytics = Analytics.shared
    }
    
    /// Reports an error to the error reporting service
    /// - Parameters:
    ///   - error: The error to report
    ///   - context: Additional context about the error
    ///   - severity: The severity level of the error
    public func reportError(
        _ error: Error,
        context: [String: Any] = [:],
        severity: ErrorSeverity = .error
    ) {
        var errorContext = context
        
        // Add common context
        errorContext["sdk_version"] = "1.0.0" // Replace with actual version
        errorContext["platform"] = "iOS"
        errorContext["os_version"] = UIDevice.current.systemVersion
        
        if let merchantId = ConfigurationManager.shared.merchantId {
            errorContext["merchant_id"] = merchantId
        }
        
        // Log the error
        logger.error("\(severity.rawValue): \(error.localizedDescription)")
        
        // Track the error in analytics
        analytics.track(.securityError, properties: [
            "error": error.localizedDescription,
            "severity": severity.rawValue,
            "context": errorContext
        ])
        
        // Report to error reporting service if configured
        if ConfigurationManager.shared.isConfigured {
            Task {
                do {
                    let errorReport = ErrorReport(
                        error: error,
                        context: errorContext,
                        severity: severity,
                        timestamp: Date()
                    )
                    
                    try await NetworkManager().requestWithoutResponse(
                        endpoint: "errors",
                        method: "POST",
                        body: errorReport
                    )
                } catch {
                    logger.error("Failed to report error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Handles a validation error
    /// - Parameters:
    ///   - field: The field that failed validation
    ///   - message: The validation error message
    public func handleValidationError(field: String, message: String) {
        let error = ValidationError(field: field, message: message)
        
        logger.error("Validation error: \(error.localizedDescription)")
        analytics.trackValidationError(field: field, error: message)
        
        reportError(error, context: [
            "field": field,
            "validation_message": message
        ], severity: .warning)
    }
    
    /// Handles a network error
    /// - Parameters:
    ///   - error: The network error
    ///   - endpoint: The API endpoint that failed
    ///   - method: The HTTP method used
    public func handleNetworkError(
        _ error: Error,
        endpoint: String,
        method: String
    ) {
        logger.error("Network error: \(error.localizedDescription)")
        analytics.trackNetworkError(endpoint: endpoint, error: error)
        
        reportError(error, context: [
            "endpoint": endpoint,
            "method": method
        ], severity: .error)
    }
    
    /// Handles a security error
    /// - Parameters:
    ///   - error: The security error
    ///   - operation: The security operation that failed
    public func handleSecurityError(
        _ error: Error,
        operation: String
    ) {
        logger.error("Security error: \(error.localizedDescription)")
        
        reportError(error, context: [
            "operation": operation
        ], severity: .critical)
    }
}

/// Severity levels for errors
public enum ErrorSeverity: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
}

/// Represents a validation error
public struct ValidationError: LocalizedError {
    public let field: String
    public let message: String
    
    public var errorDescription: String? {
        return "Validation failed for field '\(field)': \(message)"
    }
}

/// Model for error reports
private struct ErrorReport: Encodable {
    let error: Error
    let context: [String: Any]
    let severity: ErrorSeverity
    let timestamp: Date
    
    private enum CodingKeys: String, CodingKey {
        case error
        case context
        case severity
        case timestamp
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(error.localizedDescription, forKey: .error)
        try container.encode(context as? [String: String] ?? [:], forKey: .context)
        try container.encode(severity.rawValue, forKey: .severity)
        try container.encode(ISO8601DateFormatter().string(from: timestamp), forKey: .timestamp)
    }
} 