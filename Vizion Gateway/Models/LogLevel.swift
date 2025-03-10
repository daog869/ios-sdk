import SwiftUI
import Foundation

/// Log level for API and system logs
enum LogLevel: String, CaseIterable {
    case error = "ERROR"
    case warning = "WARNING"
    case info = "INFO"
    case debug = "DEBUG"
    
    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .debug: return .secondary
        }
    }
} 