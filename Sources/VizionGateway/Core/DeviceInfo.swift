import Foundation
import UIKit

/// Handles device and environment information collection
public final class DeviceInfo {
    /// Shared instance for singleton access
    public static let shared = DeviceInfo()
    
    private init() {}
    
    /// Gets information about the current device
    /// - Returns: Dictionary containing device information
    public func getDeviceInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        // Device model
        info["device_model"] = UIDevice.current.model
        info["device_name"] = UIDevice.current.name
        info["system_name"] = UIDevice.current.systemName
        info["system_version"] = UIDevice.current.systemVersion
        
        // Device identifier
        if let identifier = UIDevice.current.identifierForVendor?.uuidString {
            info["device_identifier"] = identifier
        }
        
        // Screen information
        let screen = UIScreen.main
        info["screen_width"] = "\(Int(screen.bounds.width))"
        info["screen_height"] = "\(Int(screen.bounds.height))"
        info["screen_scale"] = "\(screen.scale)"
        
        // Memory information
        let processInfo = ProcessInfo.processInfo
        info["physical_memory"] = "\(processInfo.physicalMemory / 1024 / 1024) MB"
        info["processor_count"] = "\(processInfo.processorCount)"
        
        // Locale information
        let currentLocale = Locale.current
        info["locale_identifier"] = currentLocale.identifier
        info["preferred_languages"] = Locale.preferredLanguages.joined(separator: ",")
        
        // Time zone
        let timeZone = TimeZone.current
        info["timezone_identifier"] = timeZone.identifier
        info["timezone_offset"] = "\(timeZone.secondsFromGMT() / 3600)"
        
        // Network information
        info["network_type"] = getNetworkType()
        
        // App information
        if let appInfo = Bundle.main.infoDictionary {
            info["app_version"] = appInfo["CFBundleShortVersionString"] as? String
            info["app_build"] = appInfo["CFBundleVersion"] as? String
            info["app_bundle_id"] = appInfo["CFBundleIdentifier"] as? String
        }
        
        return info
    }
    
    /// Gets the current network connection type
    /// - Returns: String describing the network connection type
    private func getNetworkType() -> String {
        // Note: For actual implementation, you would use Network.framework
        // or Reachability to determine the network type.
        // This is a placeholder implementation.
        return "unknown"
    }
    
    /// Checks if the device supports biometric authentication
    /// - Returns: Whether biometric authentication is available
    public func supportsBiometricAuthentication() -> Bool {
        // Note: For actual implementation, you would use LocalAuthentication
        // framework to check biometric capabilities.
        // This is a placeholder implementation.
        return true
    }
    
    /// Gets the device's current orientation
    /// - Returns: The current device orientation
    public func getDeviceOrientation() -> UIDeviceOrientation {
        return UIDevice.current.orientation
    }
    
    /// Gets the device's current battery state and level
    /// - Returns: Dictionary containing battery information
    public func getBatteryInfo() -> [String: Any] {
        UIDevice.current.isBatteryMonitoringEnabled = true
        defer { UIDevice.current.isBatteryMonitoringEnabled = false }
        
        var info: [String: Any] = [:]
        
        info["battery_level"] = UIDevice.current.batteryLevel
        
        switch UIDevice.current.batteryState {
        case .unknown:
            info["battery_state"] = "unknown"
        case .unplugged:
            info["battery_state"] = "unplugged"
        case .charging:
            info["battery_state"] = "charging"
        case .full:
            info["battery_state"] = "full"
        @unknown default:
            info["battery_state"] = "unknown"
        }
        
        return info
    }
    
    /// Gets information about the device's storage
    /// - Returns: Dictionary containing storage information
    public func getStorageInfo() -> [String: Int64] {
        var info: [String: Int64] = [:]
        
        do {
            let fileManager = FileManager.default
            let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let systemAttributes = try fileManager.attributesOfFileSystem(forPath: documentDirectory.path)
            
            if let freeSize = systemAttributes[.systemFreeSize] as? Int64 {
                info["free_space"] = freeSize
            }
            
            if let totalSize = systemAttributes[.systemSize] as? Int64 {
                info["total_space"] = totalSize
            }
        } catch {
            Logger.shared.error("Failed to get storage information: \(error.localizedDescription)")
        }
        
        return info
    }
    
    /// Gets information about the device's security settings
    /// - Returns: Dictionary containing security information
    public func getSecurityInfo() -> [String: Bool] {
        var info: [String: Bool] = [:]
        
        info["is_passcode_set"] = true // Placeholder - actual implementation would check this
        info["is_device_encrypted"] = true // Placeholder - actual implementation would check this
        info["is_debugging_enabled"] = isDebuggingEnabled()
        info["is_jailbroken"] = isJailbroken()
        
        return info
    }
    
    /// Checks if debugging is enabled
    private func isDebuggingEnabled() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// Checks if the device is jailbroken
    private func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let paths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/usr/bin/ssh"
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        return false
        #endif
    }
    
    /// Gets the device's current thermal state
    /// - Returns: String describing the thermal state
    public func getThermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }
} 