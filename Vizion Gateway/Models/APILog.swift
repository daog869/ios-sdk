import Foundation
import SwiftUI

struct APILog: Identifiable {
    let id: String
    let timestamp: Date
    let method: String
    let path: String
    let statusCode: Int
    let duration: TimeInterval
    let environment: String
    let level: LogLevel
    let message: String
    
    init(id: String = UUID().uuidString,
         timestamp: Date = Date(),
         method: String,
         path: String,
         statusCode: Int,
         duration: TimeInterval,
         environment: String,
         level: LogLevel = .info,
         message: String) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.path = path
        self.statusCode = statusCode
        self.duration = duration
        self.environment = environment
        self.level = level
        self.message = message
    }
}
// LogLevel enum moved to separate file: LogLevel.swift 