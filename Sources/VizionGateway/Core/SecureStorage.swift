import Foundation
import Security

/// Handles secure storage of sensitive data using Keychain
public final class SecureStorage {
    /// Shared instance for singleton access
    public static let shared = SecureStorage()
    
    /// Service identifier for Keychain items
    private let service = "com.viziongateway.sdk"
    
    private init() {}
    
    /// Stores a value securely in the Keychain
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The key to associate with the value
    public func store(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw SecureStorageError.encodingFailed
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // First, try to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Then add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw SecureStorageError.storageFailed(status: status)
        }
        
        Logger.shared.info("Successfully stored value for key: \(key)")
    }
    
    /// Retrieves a value from the Keychain
    /// - Parameter key: The key associated with the value
    /// - Returns: The stored value
    public func retrieve(forKey key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw SecureStorageError.retrievalFailed(status: status)
        }
        
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw SecureStorageError.decodingFailed
        }
        
        return value
    }
    
    /// Deletes a value from the Keychain
    /// - Parameter key: The key associated with the value to delete
    public func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStorageError.deletionFailed(status: status)
        }
        
        Logger.shared.info("Successfully deleted value for key: \(key)")
    }
    
    /// Deletes all stored values
    public func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStorageError.deletionFailed(status: status)
        }
        
        Logger.shared.info("Successfully deleted all stored values")
    }
}

/// Errors that can occur during secure storage operations
public enum SecureStorageError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case storageFailed(status: OSStatus)
    case retrievalFailed(status: OSStatus)
    case deletionFailed(status: OSStatus)
    
    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode value for storage"
        case .decodingFailed:
            return "Failed to decode stored value"
        case .storageFailed(let status):
            return "Failed to store value in Keychain (status: \(status))"
        case .retrievalFailed(let status):
            return "Failed to retrieve value from Keychain (status: \(status))"
        case .deletionFailed(let status):
            return "Failed to delete value from Keychain (status: \(status))"
        }
    }
} 