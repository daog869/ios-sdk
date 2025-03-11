import Foundation

/// Handles analytics and event tracking for the SDK
public final class Analytics {
    /// Shared instance for singleton access
    public static let shared = Analytics()
    
    /// Types of events that can be tracked
    public enum EventType: String {
        case sdkInitialized = "sdk_initialized"
        case paymentStarted = "payment_started"
        case paymentCompleted = "payment_completed"
        case paymentFailed = "payment_failed"
        case refundStarted = "refund_started"
        case refundCompleted = "refund_completed"
        case refundFailed = "refund_failed"
        case applePayStarted = "apple_pay_started"
        case applePayCompleted = "apple_pay_completed"
        case applePayFailed = "apple_pay_failed"
        case validationError = "validation_error"
        case networkError = "network_error"
        case securityError = "security_error"
    }
    
    private let networkManager: NetworkManager
    private let logger: Logger
    private let queue: DispatchQueue
    private var events: [(event: EventType, properties: [String: Any], timestamp: Date)]
    private var isFlushing: Bool
    
    private init() {
        self.networkManager = NetworkManager()
        self.logger = Logger.shared
        self.queue = DispatchQueue(label: "com.viziongateway.analytics", qos: .utility)
        self.events = []
        self.isFlushing = false
    }
    
    /// Tracks an event with optional properties
    /// - Parameters:
    ///   - event: The type of event
    ///   - properties: Additional properties for the event
    public func track(_ event: EventType, properties: [String: Any] = [:]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            var eventProperties = properties
            
            // Add common properties
            eventProperties["sdk_version"] = "1.0.0" // Replace with actual version
            eventProperties["platform"] = "iOS"
            eventProperties["os_version"] = UIDevice.current.systemVersion
            
            if let merchantId = ConfigurationManager.shared.merchantId {
                eventProperties["merchant_id"] = merchantId
            }
            
            self.events.append((event, eventProperties, Date()))
            self.logger.debug("Tracked event: \(event.rawValue)")
            
            // Flush events if we have accumulated enough
            if self.events.count >= 10 {
                self.flush()
            }
        }
    }
    
    /// Manually flushes tracked events to the server
    public func flush() {
        queue.async { [weak self] in
            guard let self = self,
                  !self.events.isEmpty,
                  !self.isFlushing,
                  ConfigurationManager.shared.isConfigured else {
                return
            }
            
            self.isFlushing = true
            
            let eventsToSend = self.events
            self.events = []
            
            // Format events for API
            let formattedEvents = eventsToSend.map { event -> [String: Any] in
                return [
                    "event_type": event.event.rawValue,
                    "properties": event.properties,
                    "timestamp": ISO8601DateFormatter().string(from: event.timestamp)
                ]
            }
            
            // Send events to analytics endpoint
            Task {
                do {
                    try await self.networkManager.requestWithoutResponse(
                        endpoint: "analytics/events",
                        method: "POST",
                        body: ["events": formattedEvents]
                    )
                    
                    self.logger.info("Successfully flushed \(eventsToSend.count) events")
                } catch {
                    self.logger.error("Failed to flush events: \(error.localizedDescription)")
                    
                    // Add events back to the queue
                    self.queue.async {
                        self.events.insert(contentsOf: eventsToSend, at: 0)
                    }
                }
                
                self.queue.async {
                    self.isFlushing = false
                }
            }
        }
    }
    
    /// Tracks a validation error
    /// - Parameters:
    ///   - field: The field that failed validation
    ///   - error: The validation error message
    public func trackValidationError(field: String, error: String) {
        track(.validationError, properties: [
            "field": field,
            "error": error
        ])
    }
    
    /// Tracks a network error
    /// - Parameters:
    ///   - endpoint: The API endpoint that failed
    ///   - error: The error that occurred
    public func trackNetworkError(endpoint: String, error: Error) {
        track(.networkError, properties: [
            "endpoint": endpoint,
            "error": error.localizedDescription
        ])
    }
    
    /// Tracks a payment attempt
    /// - Parameters:
    ///   - amount: The payment amount
    ///   - currency: The currency code
    ///   - paymentMethod: The payment method used
    public func trackPaymentAttempt(amount: Decimal, currency: String, paymentMethod: String) {
        track(.paymentStarted, properties: [
            "amount": amount,
            "currency": currency,
            "payment_method": paymentMethod
        ])
    }
    
    /// Tracks a successful payment
    /// - Parameters:
    ///   - transactionId: The transaction ID
    ///   - amount: The payment amount
    ///   - currency: The currency code
    public func trackPaymentSuccess(transactionId: String, amount: Decimal, currency: String) {
        track(.paymentCompleted, properties: [
            "transaction_id": transactionId,
            "amount": amount,
            "currency": currency
        ])
    }
    
    /// Tracks a failed payment
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - amount: The payment amount
    ///   - currency: The currency code
    public func trackPaymentFailure(error: Error, amount: Decimal, currency: String) {
        track(.paymentFailed, properties: [
            "error": error.localizedDescription,
            "amount": amount,
            "currency": currency
        ])
    }
} 