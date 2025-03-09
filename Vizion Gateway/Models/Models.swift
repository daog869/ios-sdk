// This file has been refactored to avoid duplicate model definitions
// Models have been moved to their own files (User.swift, Transaction.swift, etc.)

import SwiftUI
import SwiftData

// MARK: - Time Range
enum TimeRange: String, Codable, CaseIterable, Identifiable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case year = "This Year"
    
    var id: String { rawValue }
    
    // For dashboard filtering
    var calendarComponent: Calendar.Component? {
        switch self {
        case .today:
            return nil // Special case for today
        case .week:
            return .weekOfYear
        case .month:
            return .month
        case .year:
            return .year
        }
    }
    
    // For charts display
    var chartParameters: (dataPointCount: Int, timeInterval: TimeInterval) {
        switch self {
        case .today:
            return (24, 3600) // 24 hours, 1 hour interval
        case .week:
            return (7, 86400) // 7 days, 1 day interval
        case .month:
            return (30, 86400) // 30 days, 1 day interval
        case .year:
            return (90, 86400) // 90 days, 1 day interval
        }
    }
}

// MARK: - Payment Data
// Keeping this here as it's not defined elsewhere
struct PaymentData {
    let merchantName: String
    let amount: Decimal
    let reference: String
}

// MARK: - KYC Status
// Keeping this here as it's not defined elsewhere
enum KYCStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case submitted = "Submitted"
    case verified = "Verified"
    case rejected = "Rejected"
}

// All other models have been moved to their respective files:
// - User.swift
// - Transaction.swift
// - TimeRange, PaymentMethod, TransactionStatus, and TransactionType are defined in Transaction.swift
// - Other model files