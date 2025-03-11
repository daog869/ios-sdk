import Foundation
import CryptoKit
import UIKit
import SwiftUI

class SecurityManager {
    static let shared = SecurityManager()
    
    private init() {
        setupSecurityChecks()
    }
    
    // MARK: - Jailbreak Detection
    
    func isDeviceJailbroken() -> Bool {
        #if targetEnvironment(simulator)
            return false
        #else
            // Check for common jailbreak files
            let jailbreakPaths = [
                "/Applications/Cydia.app",
                "/Library/MobileSubstrate/MobileSubstrate.dylib",
                "/bin/bash",
                "/usr/sbin/sshd",
                "/etc/apt",
                "/usr/bin/ssh"
            ]
            
            for path in jailbreakPaths {
                if FileManager.default.fileExists(atPath: path) {
                    return true
                }
            }
            
            // Check if app can write to system
            let stringToWrite = "Jailbreak Test"
            do {
                try stringToWrite.write(toFile: "/private/jailbreak.txt", atomically: true, encoding: .utf8)
                try FileManager.default.removeItem(atPath: "/private/jailbreak.txt")
                return true
            } catch {
                return false
            }
        #endif
    }
    
    // MARK: - Certificate Pinning
    
    func setupCertificatePinning() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        
        let delegate = CertificatePinningDelegate()
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        
        // Use this session for all network requests
        URLSession.shared = session
    }
    
    // MARK: - Biometric Authentication
    
    func authenticateWithBiometrics() async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw SecurityError.biometricNotAvailable
        }
        
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to access the app"
        )
    }
    
    // MARK: - Secure Storage
    
    func secureStore(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecurityError.keychainError(status)
        }
    }
    
    func secureRetrieve(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw SecurityError.keychainError(status)
        }
        
        return data
    }
    
    // MARK: - App Security Checks
    
    private func setupSecurityChecks() {
        // Check for jailbreak
        if isDeviceJailbroken() {
            NotificationCenter.default.post(
                name: .jailbreakDetected,
                object: nil
            )
        }
        
        // Setup certificate pinning
        setupCertificatePinning()
        
        // Monitor for debugger
        #if DEBUG
        monitorForDebugger()
        #endif
    }
    
    private func monitorForDebugger() {
        #if DEBUG
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            var info = kinfo_proc()
            var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
            var size = MemoryLayout<kinfo_proc>.stride
            let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
            if junk == 0, info.kp_proc.p_flag & P_TRACED != 0 {
                NotificationCenter.default.post(
                    name: .debuggerDetected,
                    object: nil
                )
            }
        }
        #endif
    }
    
    // MARK: - Screen Security
    
    func enableScreenSecurity() {
        DispatchQueue.main.async {
            let field = UITextField()
            field.isSecureTextEntry = true
            UIApplication.shared.windows.first?.addSubview(field)
            field.centerYAnchor.constraint(equalTo: field.window!.centerYAnchor).isActive = true
            field.centerXAnchor.constraint(equalTo: field.window!.centerXAnchor).isActive = true
            field.becomeFirstResponder()
            field.resignFirstResponder()
            field.removeFromSuperview()
        }
    }
}

// MARK: - Certificate Pinning Delegate

class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, 
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust,
              let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Get public key
        let policy = SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)
        let trust = serverTrust
        let isValid = SecTrustEvaluateWithError(trust, nil)
        
        if isValid {
            // Get certificate data
            let certificateData = SecCertificateCopyData(certificate) as Data
            
            // Compare with pinned certificate
            if certificateData == pinnedCertificateData() {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }
        
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
    
    private func pinnedCertificateData() -> Data {
        // Load your pinned certificate
        guard let certificatePath = Bundle.main.path(forResource: "your-certificate", ofType: "cer"),
              let certificateData = try? Data(contentsOf: URL(fileURLWithPath: certificatePath)) else {
            return Data()
        }
        return certificateData
    }
}

// MARK: - Security Errors

enum SecurityError: Error {
    case biometricNotAvailable
    case keychainError(OSStatus)
    case certificatePinningFailed
    case jailbreakDetected
    case debuggerDetected
    
    var localizedDescription: String {
        switch self {
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .certificatePinningFailed:
            return "Certificate pinning validation failed"
        case .jailbreakDetected:
            return "Device integrity check failed"
        case .debuggerDetected:
            return "Debugger detected"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let jailbreakDetected = Notification.Name("jailbreakDetected")
    static let debuggerDetected = Notification.Name("debuggerDetected")
} 