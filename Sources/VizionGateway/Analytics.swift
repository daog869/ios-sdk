import Foundation

/// Handles analytics tracking for the SDK
public class Analytics {
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = Analytics()
    
    // MARK: - Properties
    
    /// Event types that can be tracked
    public enum EventType: String {
        /// Payment started
        case paymentStarted
        
        /// Payment completed
        case paymentCompleted
        
        /// Payment failed
        case paymentFailed
        
        /// SDK initialized
        case sdkInitialized
        
        /// SDK error
        case sdkError
        
        /// User interaction
        case userInteraction
    }
    
    /// Whether analytics tracking is enabled
    public var isEnabled = true
    
    // The backend service URL for analytics
    private let analyticsEndpoint = "https://analytics.viziongateway.com/v1/events"
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Tracking Methods
    
    /// Track an event
    /// - Parameters:
    ///   - event: The event type
    ///   - parameters: Additional parameters for the event (all values must be strings)
    public func trackEvent(_ event: EventType, parameters: [String: String]? = nil) {
        guard isEnabled else { return }
        
        // Create the event data
        var eventData: [String: String] = [
            "event": event.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Add any additional parameters
        if let parameters = parameters {
            for (key, value) in parameters {
                eventData[key] = value
            }
        }
        
        // Send the event
        sendAnalyticsEvent(eventData)
    }
    
    /// Track a payment event
    /// - Parameters:
    ///   - transactionId: The transaction ID
    ///   - amount: The payment amount
    ///   - currency: The payment currency
    ///   - status: The payment status
    ///   - method: The payment method
    public func trackPayment(
        transactionId: String,
        amount: Decimal,
        currency: String,
        status: String,
        method: String
    ) {
        // Convert all values to strings to maintain type safety
        let parameters: [String: String] = [
            "transaction_id": transactionId,
            "amount": "\(amount)",
            "currency": currency,
            "status": status,
            "method": method
        ]
        
        let eventType: EventType
        switch status.lowercased() {
        case "completed":
            eventType = .paymentCompleted
        case "failed":
            eventType = .paymentFailed
        default:
            eventType = .paymentStarted
        }
        
        trackEvent(eventType, parameters: parameters)
    }
    
    /// Track an error
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: Additional context about where the error occurred
    public func trackError(_ error: Error, context: String? = nil) {
        var parameters: [String: String] = [
            "error_message": error.localizedDescription,
            "error_type": String(describing: type(of: error))
        ]
        
        if let context = context {
            parameters["context"] = context
        }
        
        trackEvent(.sdkError, parameters: parameters)
    }
    
    // MARK: - Private Methods
    
    /// Send the analytics event to the backend
    /// - Parameter eventData: The event data to send
    private func sendAnalyticsEvent(_ eventData: [String: String]) {
        // Create the request
        guard let url = URL(string: analyticsEndpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add the API key if available
        if let authHeader = VizionGateway.shared.authorizationHeader {
            request.addValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        // Convert the event data to JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: eventData)
        } catch {
            print("Error serializing analytics event: \(error)")
            return
        }
        
        // Send the request
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("Error sending analytics event: \(error)")
            }
        }.resume()
    }
    
    /// Create a logger that can be used for debugging
    /// - Returns: A Logger instance
    public func createLogger() -> Logger {
        return Logger()
    }
}

/// Simple logger for debugging
public class Logger {
    /// Log levels
    public enum Level: String {
        /// Debug messages
        case debug
        
        /// Info messages
        case info
        
        /// Warning messages
        case warning
        
        /// Error messages
        case error
    }
    
    /// Whether logging is enabled
    public var isEnabled = true
    
    /// Log a message
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - file: The file where the log was called
    ///   - line: The line number where the log was called
    public func log(
        _ message: String,
        level: Level = .info,
        file: String = #file,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(level.rawValue.uppercased())] [\(fileName):\(line)] \(message)"
        
        print(logMessage)
        
        // Track errors in analytics
        if level == .error {
            Analytics.shared.trackEvent(.sdkError, parameters: ["message": message, "file": fileName, "line": "\(line)"])
        }
    }
}

/// Convenience function for logging
/// - Parameters:
///   - message: The message to log
///   - level: The log level
///   - file: The file where the log was called
///   - line: The line number where the log was called
public func log(
    _ message: String,
    level: Logger.Level = .info,
    file: String = #file,
    line: Int = #line
) {
    let logger = Analytics.shared.createLogger()
    logger.log(message, level: level, file: file, line: line)
} 