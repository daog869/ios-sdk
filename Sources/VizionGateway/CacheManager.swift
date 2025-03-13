import Foundation
import CommonCrypto

/// Manages caching of data in the app
public class CacheManager {
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = CacheManager()
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheAge: TimeInterval = 60 * 60 * 24 * 7 // 7 days
    
    // MARK: - Initialization
    
    private init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("VizionCache", isDirectory: true)
        
        try? fileManager.createDirectory(at: cacheDirectory, 
                                       withIntermediateDirectories: true, 
                                       attributes: nil)
    }
    
    /// Configures the cache manager
    public func configure() {
        cleanExpiredCache()
    }
    
    // MARK: - Cache Operations
    
    /// Stores data in the cache with a key
    /// - Parameters:
    ///   - data: The data to cache
    ///   - key: The cache key
    public func store(_ data: Data, forKey key: String) {
        let fileURL = cacheURL(for: key)
        try? data.write(to: fileURL)
    }
    
    /// Retrieves data from the cache for a given key
    /// - Parameter key: The cache key
    /// - Returns: The cached data, if available
    public func retrieveData(forKey key: String) -> Data? {
        let fileURL = cacheURL(for: key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        return try? Data(contentsOf: fileURL)
    }
    
    /// Removes an item from the cache
    /// - Parameter key: The cache key to remove
    public func removeItem(forKey key: String) {
        let fileURL = cacheURL(for: key)
        try? fileManager.removeItem(at: fileURL)
    }
    
    /// Clears the entire cache
    public func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, 
                                       withIntermediateDirectories: true, 
                                       attributes: nil)
    }
    
    // MARK: - Helper Methods
    
    /// Creates a URL for a cache key
    /// - Parameter key: The cache key
    /// - Returns: The file URL for the cache item
    private func cacheURL(for key: String) -> URL {
        let hashedKey = md5(key)
        return cacheDirectory.appendingPathComponent(hashedKey)
    }
    
    /// Creates an MD5 hash of a string
    /// - Parameter string: The string to hash
    /// - Returns: The MD5 hash as a string
    private func md5(_ string: String) -> String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)
        
        if let data = string.data(using: .utf8) {
            _ = data.withUnsafeBytes { body in
                CC_MD5(body.baseAddress, CC_LONG(data.count), &digest)
            }
        }
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Removes expired items from the cache
    private func cleanExpiredCache() {
        let resourceKeys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        
        guard let fileEnumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: .skipsHiddenFiles
        ) else {
            return
        }
        
        let expirationDate = Date().addingTimeInterval(-maxCacheAge)
        
        for case let fileURL as URL in fileEnumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  let modificationDate = resourceValues.contentModificationDate,
                  let isDirectory = resourceValues.isDirectory, !isDirectory else {
                continue
            }
            
            if modificationDate.compare(expirationDate) == .orderedAscending {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
} 