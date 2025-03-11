import Foundation

/// Handles API rate limiting and throttling
public final class RateLimiter {
    /// Shared instance for singleton access
    public static let shared = RateLimiter()
    
    /// Default rate limit configuration
    public static let defaultConfig = RateLimitConfig(
        requestsPerSecond: 10,
        burstSize: 20,
        timeoutInterval: 30
    )
    
    private let logger: Logger
    private let queue: DispatchQueue
    private var tokens: Double
    private var lastRefillTime: Date
    private var waitingOperations: [(Double, CheckedContinuation<Void, Error>)]
    private var config: RateLimitConfig
    
    private init() {
        self.logger = Logger.shared
        self.queue = DispatchQueue(label: "com.viziongateway.ratelimiter")
        self.tokens = Double(RateLimiter.defaultConfig.burstSize)
        self.lastRefillTime = Date()
        self.waitingOperations = []
        self.config = RateLimiter.defaultConfig
    }
    
    /// Configures the rate limiter
    /// - Parameter config: The rate limit configuration
    public func configure(_ config: RateLimitConfig) {
        queue.async {
            self.config = config
            self.tokens = Double(config.burstSize)
            self.lastRefillTime = Date()
            self.logger.info("Rate limiter configured: \(config.requestsPerSecond) requests/second, burst size: \(config.burstSize)")
        }
    }
    
    /// Acquires permission to proceed with an operation
    /// - Parameter cost: The cost of the operation in tokens (default: 1)
    public func acquire(cost: Double = 1) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.refillTokens()
                
                if self.tokens >= cost {
                    self.tokens -= cost
                    continuation.resume()
                } else {
                    let waitTime = self.calculateWaitTime(for: cost)
                    
                    if waitTime > self.config.timeoutInterval {
                        continuation.resume(throwing: RateLimitError.timeout)
                        return
                    }
                    
                    self.waitingOperations.append((cost, continuation))
                    self.scheduleRefill()
                }
            }
        }
    }
    
    /// Executes an operation with rate limiting
    /// - Parameters:
    ///   - cost: The cost of the operation in tokens
    ///   - operation: The operation to execute
    /// - Returns: The operation result
    public func execute<T>(
        cost: Double = 1,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await acquire(cost: cost)
        return try await operation()
    }
    
    /// Refills the token bucket based on elapsed time
    private func refillTokens() {
        let now = Date()
        let timePassed = now.timeIntervalSince(lastRefillTime)
        let tokensToAdd = timePassed * Double(config.requestsPerSecond)
        
        tokens = min(Double(config.burstSize), tokens + tokensToAdd)
        lastRefillTime = now
        
        processWaitingOperations()
    }
    
    /// Processes any waiting operations that can now proceed
    private func processWaitingOperations() {
        while let next = waitingOperations.first {
            if tokens >= next.0 {
                tokens -= next.0
                waitingOperations.removeFirst()
                next.1.resume()
            } else {
                break
            }
        }
    }
    
    /// Calculates the wait time needed for a given cost
    /// - Parameter cost: The cost in tokens
    /// - Returns: The wait time in seconds
    private func calculateWaitTime(for cost: Double) -> TimeInterval {
        let tokensNeeded = cost - tokens
        return tokensNeeded / Double(config.requestsPerSecond)
    }
    
    /// Schedules the next token refill
    private func scheduleRefill() {
        let nextRefillTime = 1.0 / Double(config.requestsPerSecond)
        
        queue.asyncAfter(deadline: .now() + nextRefillTime) { [weak self] in
            guard let self = self else { return }
            self.refillTokens()
        }
    }
    
    /// Gets the current rate limit status
    /// - Returns: Dictionary containing rate limit information
    public func getStatus() -> [String: Any] {
        var status: [String: Any] = [:]
        
        queue.sync {
            status["available_tokens"] = tokens
            status["requests_per_second"] = config.requestsPerSecond
            status["burst_size"] = config.burstSize
            status["waiting_operations"] = waitingOperations.count
            status["time_since_last_refill"] = Date().timeIntervalSince(lastRefillTime)
        }
        
        return status
    }
}

/// Configuration for rate limiting
public struct RateLimitConfig {
    /// Maximum number of requests per second
    public let requestsPerSecond: Int
    
    /// Maximum burst size (token bucket capacity)
    public let burstSize: Int
    
    /// Timeout interval for waiting operations
    public let timeoutInterval: TimeInterval
    
    public init(
        requestsPerSecond: Int,
        burstSize: Int,
        timeoutInterval: TimeInterval
    ) {
        self.requestsPerSecond = requestsPerSecond
        self.burstSize = burstSize
        self.timeoutInterval = timeoutInterval
    }
}

/// Errors that can occur during rate limiting
public enum RateLimitError: LocalizedError {
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Rate limit timeout exceeded"
        }
    }
} 