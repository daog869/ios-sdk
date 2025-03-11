import Foundation

/// Handles caching of API responses and other data
public final class CacheManager {
    /// Shared instance for singleton access
    public static let shared = CacheManager()
    
    /// Default cache configuration
    public static let defaultConfig = CacheConfig(
        maxSize: 50 * 1024 * 1024, // 50MB
        maxAge: 3600, // 1 hour
        cleanupInterval: 300 // 5 minutes
    )
    
    private let logger: Logger
    private let queue: DispatchQueue
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private var config: CacheConfig
    private var cacheEntries: [String: CacheEntry]
    private var totalSize: Int64
    private var cleanupTimer: DispatchSourceTimer?
    
    private init() {
        self.logger = Logger.shared
        self.queue = DispatchQueue(label: "com.viziongateway.cache")
        self.fileManager = FileManager.default
        self.config = CacheManager.defaultConfig
        self.cacheEntries = [:]
        self.totalSize = 0
        
        // Set up cache directory
        let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cacheURL.appendingPathComponent("com.viziongateway.cache")
        
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create cache directory: \(error.localizedDescription)")
        }
        
        // Load existing cache entries
        loadCacheEntries()
        
        // Start cleanup timer
        startCleanupTimer()
    }
    
    /// Configures the cache manager
    /// - Parameter config: The cache configuration
    public func configure(_ config: CacheConfig) {
        queue.async {
            self.config = config
            self.logger.info("Cache configured: maxSize=\(ByteCountFormatter.string(fromByteCount: Int64(config.maxSize), countStyle: .file)), maxAge=\(config.maxAge)s")
            self.performCleanup()
        }
    }
    
    /// Stores data in the cache
    /// - Parameters:
    ///   - data: The data to store
    ///   - key: The cache key
    ///   - expiration: Optional custom expiration time
    public func store(_ data: Data, forKey key: String, expiration: TimeInterval? = nil) {
        queue.async {
            let expirationDate = Date().addingTimeInterval(expiration ?? self.config.maxAge)
            let entry = CacheEntry(key: key, size: Int64(data.count), expirationDate: expirationDate)
            
            // Check if we need to make space
            if self.totalSize + entry.size > self.config.maxSize {
                self.makeSpace(for: entry.size)
            }
            
            // Write data to file
            let fileURL = self.fileURL(for: key)
            do {
                try data.write(to: fileURL)
                
                // Update cache entry
                if let oldEntry = self.cacheEntries[key] {
                    self.totalSize -= oldEntry.size
                }
                self.cacheEntries[key] = entry
                self.totalSize += entry.size
                
                self.logger.debug("Stored \(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)) for key: \(key)")
            } catch {
                self.logger.error("Failed to write cache file: \(error.localizedDescription)")
            }
        }
    }
    
    /// Retrieves data from the cache
    /// - Parameter key: The cache key
    /// - Returns: The cached data, if available and not expired
    public func retrieve(forKey key: String) -> Data? {
        var result: Data?
        
        queue.sync {
            guard let entry = cacheEntries[key],
                  !entry.isExpired else {
                return
            }
            
            let fileURL = fileURL(for: key)
            do {
                result = try Data(contentsOf: fileURL)
                logger.debug("Retrieved \(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)) for key: \(key)")
            } catch {
                logger.error("Failed to read cache file: \(error.localizedDescription)")
                // Remove invalid entry
                remove(forKey: key)
            }
        }
        
        return result
    }
    
    /// Removes data from the cache
    /// - Parameter key: The cache key
    public func remove(forKey key: String) {
        queue.async {
            guard let entry = self.cacheEntries[key] else { return }
            
            let fileURL = self.fileURL(for: key)
            do {
                try self.fileManager.removeItem(at: fileURL)
                self.cacheEntries.removeValue(forKey: key)
                self.totalSize -= entry.size
                self.logger.debug("Removed cache entry for key: \(key)")
            } catch {
                self.logger.error("Failed to remove cache file: \(error.localizedDescription)")
            }
        }
    }
    
    /// Clears all cached data
    public func clearAll() {
        queue.async {
            do {
                try self.fileManager.removeItem(at: self.cacheDirectory)
                try self.fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
                
                self.cacheEntries.removeAll()
                self.totalSize = 0
                self.logger.info("Cache cleared")
            } catch {
                self.logger.error("Failed to clear cache: \(error.localizedDescription)")
            }
        }
    }
    
    /// Gets the current cache status
    /// - Returns: Dictionary containing cache information
    public func getStatus() -> [String: Any] {
        var status: [String: Any] = [:]
        
        queue.sync {
            status["total_size"] = totalSize
            status["entry_count"] = cacheEntries.count
            status["max_size"] = config.maxSize
            status["available_space"] = config.maxSize - totalSize
            status["utilization"] = Double(totalSize) / Double(config.maxSize)
        }
        
        return status
    }
    
    // MARK: - Private Methods
    
    private func fileURL(for key: String) -> URL {
        return cacheDirectory.appendingPathComponent(key.md5Hash)
    }
    
    private func loadCacheEntries() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            for file in files {
                let key = file.lastPathComponent
                if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                   let size = attributes[.size] as? Int64 {
                    let entry = CacheEntry(key: key, size: size, expirationDate: Date().addingTimeInterval(config.maxAge))
                    cacheEntries[key] = entry
                    totalSize += size
                }
            }
            
            logger.info("Loaded \(cacheEntries.count) cache entries, total size: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
        } catch {
            logger.error("Failed to load cache entries: \(error.localizedDescription)")
        }
    }
    
    private func makeSpace(for size: Int64) {
        // Sort entries by expiration date
        let sortedEntries = cacheEntries.values.sorted { $0.expirationDate < $1.expirationDate }
        
        var spaceNeeded = totalSize + size - config.maxSize
        
        for entry in sortedEntries {
            guard spaceNeeded > 0 else { break }
            
            remove(forKey: entry.key)
            spaceNeeded -= entry.size
        }
    }
    
    private func startCleanupTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + config.cleanupInterval, repeating: config.cleanupInterval)
        timer.setEventHandler { [weak self] in
            self?.performCleanup()
        }
        timer.resume()
        cleanupTimer = timer
    }
    
    private func performCleanup() {
        let now = Date()
        let expiredEntries = cacheEntries.values.filter { $0.expirationDate < now }
        
        for entry in expiredEntries {
            remove(forKey: entry.key)
        }
        
        if !expiredEntries.isEmpty {
            logger.debug("Cleaned up \(expiredEntries.count) expired cache entries")
        }
    }
}

/// Configuration for caching
public struct CacheConfig {
    /// Maximum cache size in bytes
    public let maxSize: Int
    
    /// Maximum age of cache entries in seconds
    public let maxAge: TimeInterval
    
    /// Interval for cleanup operations in seconds
    public let cleanupInterval: TimeInterval
    
    public init(
        maxSize: Int,
        maxAge: TimeInterval,
        cleanupInterval: TimeInterval
    ) {
        self.maxSize = maxSize
        self.maxAge = maxAge
        self.cleanupInterval = cleanupInterval
    }
}

/// Represents a cache entry
private struct CacheEntry {
    let key: String
    let size: Int64
    let expirationDate: Date
    
    var isExpired: Bool {
        return Date() > expirationDate
    }
}

// MARK: - String Extension

private extension String {
    /// Computes MD5 hash of the string
    var md5Hash: String {
        let data = Data(utf8)
        var digest = [UInt8](repeating: 0, count: 16)
        _ = data.withUnsafeBytes { bytes in
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
} 