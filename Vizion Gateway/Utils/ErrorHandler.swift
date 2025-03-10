import Foundation
import SwiftUI

// MARK: - App Error Enum

/// Standardized error types for the application
enum AppError: Error, Identifiable {
    case networkError(String)
    case authenticationError(String)
    case databaseError(String)
    case validationError(String)
    case permissionError(String)
    case serverError(String)
    case unknownError(String)
    
    // Conform to Identifiable for SwiftUI
    var id: String {
        switch self {
        case .networkError(let message): return "network_\(message.hashValue)"
        case .authenticationError(let message): return "auth_\(message.hashValue)"
        case .databaseError(let message): return "db_\(message.hashValue)"
        case .validationError(let message): return "validation_\(message.hashValue)"
        case .permissionError(let message): return "permission_\(message.hashValue)"
        case .serverError(let message): return "server_\(message.hashValue)"
        case .unknownError(let message): return "unknown_\(message.hashValue)"
        }
    }
    
    // Human readable error message
    var message: String {
        switch self {
        case .networkError(let message): return "Network Error: \(message)"
        case .authenticationError(let message): return "Authentication Error: \(message)"
        case .databaseError(let message): return "Database Error: \(message)"
        case .validationError(let message): return "Validation Error: \(message)"
        case .permissionError(let message): return "Permission Error: \(message)"
        case .serverError(let message): return "Server Error: \(message)"
        case .unknownError(let message): return "Unknown Error: \(message)"
        }
    }
    
    // Convert any Error to an AppError
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Handle NSError domains
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSURLErrorDomain:
                return .networkError(nsError.localizedDescription)
            case "FIRAuthErrorDomain":
                return .authenticationError(nsError.localizedDescription)
            case "FIRFirestoreErrorDomain":
                return .databaseError(nsError.localizedDescription)
            default:
                break
            }
        }
        
        return .unknownError(error.localizedDescription)
    }
}

// MARK: - Error Handler Class

/// Singleton class for handling errors throughout the app
class ErrorHandler {
    static let shared = ErrorHandler()
    
    // Optional callback for analytics tracking
    var analyticsCallback: ((AppError) -> Void)?
    
    // Private initializer for singleton
    private init() {}
    
    /// Handles an error by logging it and optionally sending to analytics
    /// - Parameter error: The error to handle
    /// - Returns: An AppError that can be displayed to the user
    func handle(_ error: Error) -> AppError {
        let appError = AppError.from(error)
        
        // Log the error
        #if DEBUG
        print("🔴 ERROR: \(appError.message)")
        #endif
        
        // Send to analytics if callback is set
        analyticsCallback?(appError)
        
        return appError
    }
    
    /// Handles an error and returns a localized user-friendly message
    /// - Parameter error: The error to handle
    /// - Returns: A user-friendly error message
    func handleWithMessage(_ error: Error) -> String {
        return handle(error).message
    }
    
    /// Executes a throwing function and handles any errors
    /// - Parameters:
    ///   - operation: A string describing the operation (for logging)
    ///   - action: The async throwing closure to execute
    /// - Returns: A Result type with either success or the handled AppError
    func tryAsync<T>(_ operation: String, action: @escaping () async throws -> T) async -> Result<T, AppError> {
        do {
            let result = try await action()
            return .success(result)
        } catch {
            let appError = handle(error)
            print("Operation failed: \(operation) - \(appError.message)")
            return .failure(appError)
        }
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Adds standardized error handling to a view
    /// - Parameters:
    ///   - error: Binding to an optional AppError
    ///   - action: Optional action to perform when the error is dismissed
    /// - Returns: A view with error handling
    func withErrorHandling(_ error: Binding<AppError?>, onDismiss action: (() -> Void)? = nil) -> some View {
        return self.alert(item: error) { currentError in
            Alert(
                title: Text("Error"),
                message: Text(currentError.message),
                dismissButton: .default(Text("OK")) {
                    action?()
                }
            )
        }
    }
    
    /// Adds loading and error handling to a view
    /// - Parameters:
    ///   - isLoading: Binding to a boolean indicating if a task is in progress
    ///   - error: Binding to an optional AppError
    ///   - action: Optional action to perform when the error is dismissed
    /// - Returns: A view with loading indicator and error handling
    func withLoadingAndError(_ isLoading: Binding<Bool>, error: Binding<AppError?>, onErrorDismiss action: (() -> Void)? = nil) -> some View {
        return self
            .overlay {
                if isLoading.wrappedValue {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                        
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
            }
            .withErrorHandling(error, onDismiss: action)
    }
}

// MARK: - Task Extension

extension Task where Failure == Error {
    /// Execute a task with standardized error handling
    /// - Parameters:
    ///   - priority: Task priority
    ///   - operation: Description of the operation
    ///   - errorHandler: The error handler to use
    ///   - action: The action to perform
    /// - Returns: A task that handles errors through the ErrorHandler
    @discardableResult
    static func withErrorHandling<T>(
        priority: TaskPriority? = nil,
        operation: String,
        errorHandler: ErrorHandler = ErrorHandler.shared,
        action: @escaping () async throws -> T
    ) -> Task<T?, Never> {
        return Task<T?, Never>(priority: priority) { 
            do {
                let result = try await action()
                return result
            } catch {
                let _ = errorHandler.handle(error)
                // Return nil in case of error
                return nil
            }
        }
    }
} 