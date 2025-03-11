import Foundation
import LocalAuthentication

/// Handles biometric authentication using Face ID or Touch ID
public final class BiometricAuth {
    /// Shared instance for singleton access
    public static let shared = BiometricAuth()
    
    private let context: LAContext
    private let logger: Logger
    
    private init() {
        self.context = LAContext()
        self.logger = Logger.shared
    }
    
    /// Gets the available biometric type
    /// - Returns: The type of biometric authentication available
    public func getBiometricType() -> BiometricType {
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                logger.debug("Biometric availability check failed: \(error.localizedDescription)")
            }
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }
    
    /// Checks if biometric authentication is available
    /// - Returns: Whether biometric authentication can be used
    public func isBiometricAvailable() -> Bool {
        return getBiometricType() != .none
    }
    
    /// Authenticates the user using biometrics
    /// - Parameters:
    ///   - reason: The reason for requesting authentication
    ///   - fallbackTitle: Optional title for the fallback button
    ///   - cancelTitle: Optional title for the cancel button
    /// - Returns: The authentication result
    public func authenticate(
        reason: String,
        fallbackTitle: String? = nil,
        cancelTitle: String? = nil
    ) async -> BiometricResult {
        // Reset context for new evaluation
        context.invalidate()
        let newContext = LAContext()
        
        // Configure localized buttons if provided
        if let fallbackTitle = fallbackTitle {
            newContext.localizedFallbackTitle = fallbackTitle
        }
        
        if let cancelTitle = cancelTitle {
            newContext.localizedCancelTitle = cancelTitle
        }
        
        var error: NSError?
        guard newContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                logger.error("Biometric authentication not available: \(error.localizedDescription)")
                return .failure(.notAvailable(error))
            }
            return .failure(.notAvailable(nil))
        }
        
        do {
            let success = try await newContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                logger.info("Biometric authentication successful")
                return .success
            } else {
                logger.error("Biometric authentication failed")
                return .failure(.failed)
            }
        } catch let error as LAError {
            logger.error("Biometric authentication error: \(error.localizedDescription)")
            
            switch error.code {
            case .userCancel:
                return .failure(.canceled)
            case .userFallback:
                return .failure(.fallback)
            case .biometryLockout:
                return .failure(.lockout)
            case .biometryNotEnrolled:
                return .failure(.notEnrolled)
            case .biometryNotAvailable:
                return .failure(.notAvailable(error))
            default:
                return .failure(.failed)
            }
        } catch {
            logger.error("Unexpected authentication error: \(error.localizedDescription)")
            return .failure(.failed)
        }
    }
    
    /// Checks if a specific biometric type is enrolled
    /// - Parameter type: The biometric type to check
    /// - Returns: Whether the biometric type is enrolled
    public func isEnrolled(type: BiometricType) -> Bool {
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        
        switch type {
        case .faceID:
            return context.biometryType == .faceID
        case .touchID:
            return context.biometryType == .touchID
        case .none:
            return false
        }
    }
    
    /// Gets the localized reason for biometric usage
    /// - Returns: The localized reason string
    public func getLocalizedReason() -> String {
        switch getBiometricType() {
        case .faceID:
            return NSLocalizedString(
                "Authenticate using Face ID to complete the payment",
                comment: "Face ID authentication reason"
            )
        case .touchID:
            return NSLocalizedString(
                "Authenticate using Touch ID to complete the payment",
                comment: "Touch ID authentication reason"
            )
        case .none:
            return NSLocalizedString(
                "Biometric authentication is not available",
                comment: "No biometric authentication available"
            )
        }
    }
}

/// Types of biometric authentication
public enum BiometricType {
    case none
    case touchID
    case faceID
    
    /// Returns a user-friendly name for the biometric type
    public var displayName: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        }
    }
}

/// Result of biometric authentication
public enum BiometricResult {
    case success
    case failure(BiometricError)
}

/// Errors that can occur during biometric authentication
public enum BiometricError: LocalizedError {
    case notAvailable(Error?)
    case notEnrolled
    case lockout
    case canceled
    case fallback
    case failed
    
    public var errorDescription: String? {
        switch self {
        case .notAvailable(let error):
            if let error = error {
                return "Biometric authentication not available: \(error.localizedDescription)"
            }
            return "Biometric authentication not available"
        case .notEnrolled:
            return "Biometric authentication not enrolled"
        case .lockout:
            return "Biometric authentication is locked out"
        case .canceled:
            return "Biometric authentication was canceled"
        case .fallback:
            return "User selected fallback authentication"
        case .failed:
            return "Biometric authentication failed"
        }
    }
} 