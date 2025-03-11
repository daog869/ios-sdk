import Foundation

/// Handles retries and exponential backoff for network requests
public final class RetryManager {
    /// Shared instance for singleton access
    public static let shared = RetryManager()
    
    /// Default retry configuration
    public static let defaultConfig = RetryConfig(
        maxAttempts: 3,
        initialDelay: 0.5,
        maxDelay: 5.0,
        multiplier: 2.0,
        jitter: 0.1
    )
    
    private let logger: Logger
    
    private init() {
        self.logger = Logger.shared
    }
    
    /// Executes an operation with retry logic
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - config: The retry configuration
    ///   - shouldRetry: Closure that determines if a retry should be attempted
    /// - Returns: The operation result
    public func execute<T>(
        operation: @escaping () async throws -> T,
        config: RetryConfig = defaultConfig,
        shouldRetry: @escaping (Error) -> Bool = { _ in true }
    ) async throws -> T {
        var attempt = 1
        var delay = config.initialDelay
        
        while true {
            do {
                return try await operation()
            } catch {
                if attempt >= config.maxAttempts || !shouldRetry(error) {
                    logger.error("Operation failed after \(attempt) attempts: \(error.localizedDescription)")
                    throw error
                }
                
                // Calculate next delay with jitter
                let jitter = Double.random(in: -config.jitter...config.jitter)
                let nextDelay = min(delay * config.multiplier, config.maxDelay)
                let actualDelay = max(0, delay + (delay * jitter))
                
                logger.info("Attempt \(attempt) failed, retrying in \(String(format: "%.2f", actualDelay))s")
                
                try await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
                
                attempt += 1
                delay = nextDelay
            }
        }
    }
    
    /// Executes an operation with retry logic and progress updates
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - config: The retry configuration
    ///   - shouldRetry: Closure that determines if a retry should be attempted
    ///   - progress: Closure called with retry progress updates
    /// - Returns: The operation result
    public func executeWithProgress<T>(
        operation: @escaping () async throws -> T,
        config: RetryConfig = defaultConfig,
        shouldRetry: @escaping (Error) -> Bool = { _ in true },
        progress: @escaping (RetryProgress) -> Void
    ) async throws -> T {
        var attempt = 1
        var delay = config.initialDelay
        
        while true {
            do {
                let result = try await operation()
                
                progress(RetryProgress(
                    attempt: attempt,
                    maxAttempts: config.maxAttempts,
                    delay: 0,
                    error: nil,
                    isComplete: true,
                    isSuccess: true
                ))
                
                return result
            } catch {
                let shouldTryAgain = attempt < config.maxAttempts && shouldRetry(error)
                
                // Calculate next delay with jitter
                let jitter = Double.random(in: -config.jitter...config.jitter)
                let nextDelay = min(delay * config.multiplier, config.maxDelay)
                let actualDelay = shouldTryAgain ? max(0, delay + (delay * jitter)) : 0
                
                progress(RetryProgress(
                    attempt: attempt,
                    maxAttempts: config.maxAttempts,
                    delay: actualDelay,
                    error: error,
                    isComplete: !shouldTryAgain,
                    isSuccess: false
                ))
                
                if !shouldTryAgain {
                    logger.error("Operation failed after \(attempt) attempts: \(error.localizedDescription)")
                    throw error
                }
                
                try await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
                
                attempt += 1
                delay = nextDelay
            }
        }
    }
    
    /// Determines if an error should be retried based on common criteria
    /// - Parameter error: The error to evaluate
    /// - Returns: Whether the error should be retried
    public func shouldRetryError(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized, .decodingError:
                return false
            case .networkError, .serverError, .noData:
                return true
            default:
                return false
            }
        }
        
        // Check for common transient errors
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorInternationalRoamingOff,
                 NSURLErrorCallIsActive,
                 NSURLErrorDataNotAllowed,
                 NSURLErrorRequestBodyStreamExhausted:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
}

/// Configuration for retry behavior
public struct RetryConfig {
    /// Maximum number of attempts
    public let maxAttempts: Int
    
    /// Initial delay between attempts (in seconds)
    public let initialDelay: Double
    
    /// Maximum delay between attempts (in seconds)
    public let maxDelay: Double
    
    /// Multiplier for exponential backoff
    public let multiplier: Double
    
    /// Jitter factor for randomizing delays (0.0 to 1.0)
    public let jitter: Double
    
    public init(
        maxAttempts: Int,
        initialDelay: Double,
        maxDelay: Double,
        multiplier: Double,
        jitter: Double
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.jitter = min(max(jitter, 0.0), 1.0)
    }
}

/// Progress information for retry operations
public struct RetryProgress {
    /// Current attempt number
    public let attempt: Int
    
    /// Maximum number of attempts
    public let maxAttempts: Int
    
    /// Delay until next attempt (in seconds)
    public let delay: Double
    
    /// Error from the last attempt
    public let error: Error?
    
    /// Whether the operation is complete
    public let isComplete: Bool
    
    /// Whether the operation was successful
    public let isSuccess: Bool
} 