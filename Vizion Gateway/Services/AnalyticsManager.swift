import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {
        setupCrashlytics()
    }
    
    // MARK: - Configuration
    
    private func setupCrashlytics() {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    }
    
    // MARK: - User Properties
    
    func setUserProperties(userId: String, properties: [String: Any]) {
        Analytics.setUserID(userId)
        
        for (key, value) in properties {
            Analytics.setUserProperty(String(describing: value), forName: key)
        }
        
        // Set user ID in Crashlytics
        Crashlytics.crashlytics().setUserID(userId)
    }
    
    // MARK: - Screen Tracking
    
    func logScreen(_ screenName: ScreenName, parameters: [String: Any]? = nil) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName.rawValue,
            AnalyticsParameterScreenClass: screenName.rawValue + "View"
        ])
    }
    
    // MARK: - Event Tracking
    
    func logEvent(_ event: AnalyticsEvent, parameters: [String: Any]? = nil) {
        Analytics.logEvent(event.rawValue, parameters: parameters)
    }
    
    // MARK: - Transaction Tracking
    
    func logTransaction(_ transaction: WalletTransaction) {
        var parameters: [String: Any] = [
            "transaction_id": transaction.id,
            "amount": transaction.amount,
            "currency": transaction.currency.rawValue,
            "type": transaction.type.rawValue,
            "status": transaction.status.rawValue
        ]
        
        if let description = transaction.transactionDescription {
            parameters["description"] = description
        }
        
        Analytics.logEvent(AnalyticsEventPurchase, parameters: parameters)
    }
    
    // MARK: - Error Tracking
    
    func logError(_ error: Error, parameters: [String: Any]? = nil) {
        var errorParameters = [
            "error_description": error.localizedDescription,
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code
        ] as [String: Any]
        
        if let additionalParams = parameters {
            errorParameters.merge(additionalParams) { current, _ in current }
        }
        
        Analytics.logEvent("error", parameters: errorParameters)
        Crashlytics.crashlytics().record(error: error)
    }
    
    // MARK: - Performance Monitoring
    
    func startMeasuring(_ name: String) -> String {
        let trace = Performance.startTrace(name: name)
        return name
    }
    
    func stopMeasuring(_ name: String) {
        Performance.stopTrace(name: name)
    }
    
    func incrementMetric(_ name: String, by value: Int = 1) {
        if let trace = Performance.trace(name: name) {
            trace.incrementMetric(name, by: value)
        }
    }
    
    // MARK: - User Engagement
    
    func logUserEngagement(type: EngagementType, duration: TimeInterval) {
        Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
            "engagement_type": type.rawValue,
            "duration": duration
        ])
    }
    
    // MARK: - Feature Usage
    
    func logFeatureUsage(_ feature: AppFeature) {
        Analytics.logEvent("feature_used", parameters: [
            "feature_name": feature.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Custom Metrics
    
    func logCustomMetric(_ metric: CustomMetric, value: Double) {
        Analytics.logEvent("custom_metric", parameters: [
            "metric_name": metric.rawValue,
            "value": value
        ])
    }
}

// MARK: - Supporting Types

enum ScreenName: String {
    case login = "Login"
    case signup = "Signup"
    case dashboard = "Dashboard"
    case wallet = "Wallet"
    case transactions = "Transactions"
    case settings = "Settings"
    case profile = "Profile"
    case security = "Security"
}

enum AnalyticsEvent: String {
    case login = "login"
    case signup = "signup"
    case logout = "logout"
    case transactionInitiated = "transaction_initiated"
    case transactionCompleted = "transaction_completed"
    case transactionFailed = "transaction_failed"
    case settingsChanged = "settings_changed"
    case profileUpdated = "profile_updated"
    case securityEvent = "security_event"
    case errorOccurred = "error_occurred"
}

enum EngagementType: String {
    case viewContent = "view_content"
    case interaction = "interaction"
    case transaction = "transaction"
    case social = "social"
}

enum AppFeature: String {
    case biometricAuth = "biometric_auth"
    case pushNotifications = "push_notifications"
    case darkMode = "dark_mode"
    case search = "search"
    case filter = "filter"
    case sort = "sort"
    case export = "export"
    case share = "share"
}

enum CustomMetric: String {
    case loadTime = "load_time"
    case responseTime = "response_time"
    case sessionDuration = "session_duration"
    case screenViewTime = "screen_view_time"
    case transactionValue = "transaction_value"
    case userRetention = "user_retention"
}

// MARK: - Performance Monitoring

class Performance {
    private static var traces: [String: Date] = [:]
    
    static func startTrace(name: String) -> String {
        traces[name] = Date()
        return name
    }
    
    static func stopTrace(name: String) {
        guard let startDate = traces[name] else { return }
        let duration = Date().timeIntervalSince(startDate)
        
        Analytics.logEvent("performance", parameters: [
            "trace_name": name,
            "duration": duration
        ])
        
        traces.removeValue(forKey: name)
    }
    
    static func trace(name: String) -> Performance? {
        return traces[name] != nil ? Performance() : nil
    }
    
    func incrementMetric(_ name: String, by value: Int) {
        Analytics.logEvent("metric_increment", parameters: [
            "metric_name": name,
            "increment_value": value
        ])
    }
} 