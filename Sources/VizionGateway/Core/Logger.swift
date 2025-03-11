import Foundation
import os.log

/// Handles logging for the VizionGateway SDK
public final class Logger {
    /// Log levels for different types of messages
    public enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        
        fileprivate var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            }
        }
    }
    
    /// Shared instance for singleton access
    public static let shared = Logger()
    
    /// Whether debug logging is enabled
    public var isDebugEnabled = false
    
    /// The underlying system logger
    private let osLog: OSLog
    
    private init() {
        self.osLog = OSLog(subsystem: "com.viziongateway.sdk", category: "VizionGateway")
    }
    
    /// Logs a message with the specified level
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The severity level of the log
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line number where the log was called
    public func log(
        _ message: String,
        level: Level = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Skip debug messages if debug logging is disabled
        if level == .debug && !isDebugEnabled {
            return
        }
        
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)"
        
        os_log("%{public}@", log: osLog, type: level.osLogType, logMessage)
        
        #if DEBUG
        // Print to console in debug builds
        print(logMessage)
        #endif
    }
    
    /// Logs a debug message
    /// - Parameters:
    ///   - message: The debug message
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line number where the log was called
    public func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    /// Logs an info message
    /// - Parameters:
    ///   - message: The info message
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line number where the log was called
    public func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    /// Logs a warning message
    /// - Parameters:
    ///   - message: The warning message
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line number where the log was called
    public func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    /// Logs an error message
    /// - Parameters:
    ///   - message: The error message
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line number where the log was called
    public func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, file: file, function: function, line: line)
    }
} 