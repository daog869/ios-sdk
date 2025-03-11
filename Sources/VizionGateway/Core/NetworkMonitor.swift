import Foundation
import Network

/// Handles network reachability and monitoring
public final class NetworkMonitor {
    /// Shared instance for singleton access
    public static let shared = NetworkMonitor()
    
    /// The current network path
    private let monitor: NWPathMonitor
    
    /// Queue for processing network updates
    private let queue = DispatchQueue(label: "com.viziongateway.networkmonitor")
    
    /// Current network status
    private(set) var isConnected = false
    
    /// Current connection type
    private(set) var connectionType: ConnectionType = .unknown
    
    /// Current network interface
    private(set) var interfaceType: InterfaceType = .unknown
    
    /// Delegate for network status updates
    public weak var delegate: NetworkMonitorDelegate?
    
    private init() {
        self.monitor = NWPathMonitor()
    }
    
    /// Starts monitoring network status
    public func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            // Update connection status
            let isConnected = path.status == .satisfied
            let previousStatus = self.isConnected
            self.isConnected = isConnected
            
            // Update connection type
            let connectionType = self.determineConnectionType(from: path)
            let previousConnectionType = self.connectionType
            self.connectionType = connectionType
            
            // Update interface type
            let interfaceType = self.determineInterfaceType(from: path)
            let previousInterfaceType = self.interfaceType
            self.interfaceType = interfaceType
            
            // Log changes
            if previousStatus != isConnected {
                Logger.shared.info("Network connection status changed: \(isConnected ? "connected" : "disconnected")")
            }
            
            if previousConnectionType != connectionType {
                Logger.shared.info("Network connection type changed: \(connectionType.rawValue)")
            }
            
            if previousInterfaceType != interfaceType {
                Logger.shared.info("Network interface type changed: \(interfaceType.rawValue)")
            }
            
            // Notify delegate on main queue
            DispatchQueue.main.async {
                self.delegate?.networkStatusDidChange(
                    isConnected: isConnected,
                    connectionType: connectionType,
                    interfaceType: interfaceType
                )
            }
            
            // Track analytics
            Analytics.shared.track(.networkError, properties: [
                "status": isConnected ? "connected" : "disconnected",
                "connection_type": connectionType.rawValue,
                "interface_type": interfaceType.rawValue,
                "is_expensive": path.isExpensive,
                "is_constrained": path.isConstrained
            ])
        }
        
        monitor.start(queue: queue)
        Logger.shared.info("Network monitoring started")
    }
    
    /// Stops monitoring network status
    public func stopMonitoring() {
        monitor.cancel()
        Logger.shared.info("Network monitoring stopped")
    }
    
    /// Determines the connection type from a network path
    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.usesInterfaceType(.loopback) {
            return .loopback
        } else {
            return .unknown
        }
    }
    
    /// Determines the interface type from a network path
    private func determineInterfaceType(from path: NWPath) -> InterfaceType {
        if path.availableInterfaces.isEmpty {
            return .unknown
        }
        
        let interface = path.availableInterfaces[0]
        
        switch interface.type {
        case .wifi:
            return .wifi
        case .cellular:
            return .cellular
        case .wiredEthernet:
            return .ethernet
        case .loopback:
            return .loopback
        default:
            return .unknown
        }
    }
    
    /// Gets the current network status
    /// - Returns: Dictionary containing network status information
    public func getNetworkStatus() -> [String: Any] {
        return [
            "is_connected": isConnected,
            "connection_type": connectionType.rawValue,
            "interface_type": interfaceType.rawValue,
            "is_expensive": monitor.currentPath.isExpensive,
            "is_constrained": monitor.currentPath.isConstrained
        ]
    }
    
    /// Checks if the current network is suitable for large data transfers
    /// - Returns: Whether the network is suitable for large transfers
    public func isSuitableForLargeTransfers() -> Bool {
        let path = monitor.currentPath
        return !path.isExpensive && !path.isConstrained
    }
}

/// Types of network connections
public enum ConnectionType: String {
    case wifi = "wifi"
    case cellular = "cellular"
    case ethernet = "ethernet"
    case loopback = "loopback"
    case unknown = "unknown"
}

/// Types of network interfaces
public enum InterfaceType: String {
    case wifi = "wifi"
    case cellular = "cellular"
    case ethernet = "ethernet"
    case loopback = "loopback"
    case unknown = "unknown"
}

/// Protocol for network status updates
public protocol NetworkMonitorDelegate: AnyObject {
    /// Called when network status changes
    /// - Parameters:
    ///   - isConnected: Whether the device is connected to the network
    ///   - connectionType: The type of network connection
    ///   - interfaceType: The type of network interface
    func networkStatusDidChange(
        isConnected: Bool,
        connectionType: ConnectionType,
        interfaceType: InterfaceType
    )
} 