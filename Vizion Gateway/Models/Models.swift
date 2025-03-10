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

// MARK: - Merchant Types
enum MerchantType: String, Codable, CaseIterable, Identifiable {
    case pos = "POS Terminal" // Physical point-of-sale terminal
    case api = "API Integration" // Website/app integration via API
    case hybrid = "Hybrid" // Both POS and API
    
    var id: String { rawValue }
}

// MARK: - Merchant Status
enum MerchantStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case active = "Active"
    case suspended = "Suspended"
    case terminated = "Terminated"
}

// MARK: - Bank Type
enum BankType: String, Codable, CaseIterable, Identifiable {
    case nationalBank = "National Bank"
    case firstCaribbean = "FirstCaribbean"
    case republicBank = "Republic Bank"
    case bankOfNevis = "Bank of Nevis"
    case rbtt = "RBTT Bank"
    case scotiabank = "Scotiabank"
    case stKittsNevisAnguillaBank = "St. Kitts-Nevis-Anguilla National Bank"
    case other = "Other"
    
    var id: String { rawValue }
}

// MARK: - API Scopes
enum APIScope: String, Codable, CaseIterable {
    case payments = "payments"           // Process payments and refunds
    case payouts = "payouts"            // Handle payouts to merchants
    case customers = "customers"         // Manage customer data
    case disputes = "disputes"          // Handle disputes and chargebacks
    case webhooks = "webhooks"          // Manage webhook endpoints
    case reports = "reports"            // Access reporting and analytics
    case terminals = "terminals"        // Manage POS terminals
    case settings = "settings"          // Access merchant settings
    
    var description: String {
        switch self {
        case .payments:
            return "Process payments and issue refunds"
        case .payouts:
            return "Manage merchant payouts"
        case .customers:
            return "Create and manage customer data"
        case .disputes:
            return "Handle disputes and chargebacks"
        case .webhooks:
            return "Configure webhook endpoints"
        case .reports:
            return "Access transaction reports and analytics"
        case .terminals:
            return "Manage POS terminals"
        case .settings:
            return "Access and update merchant settings"
        }
    }
}

// MARK: - API Key
struct APIKey: Identifiable, Codable {
    var id: String
    var key: String
    var name: String
    var merchantId: String
    var active: Bool
    var scopes: Set<APIScope>
    var createdAt: Date
    var lastUsed: Date?
    var expiresAt: Date?
    var ipRestrictions: [String]?
    var metadata: [String: String]?
    
    // Whether this is a live or test key
    var isLive: Bool {
        return !key.contains("_test_")
    }
    
    // Default initializer with all scopes enabled
    init(id: String, key: String, name: String, merchantId: String, active: Bool = true, scopes: Set<APIScope>? = nil, createdAt: Date = Date(), lastUsed: Date? = nil, expiresAt: Date? = nil, ipRestrictions: [String]? = nil, metadata: [String: String]? = nil) {
        self.id = id
        self.key = key
        self.name = name
        self.merchantId = merchantId
        self.active = active
        self.scopes = scopes ?? Set(APIScope.allCases)
        self.createdAt = createdAt
        self.lastUsed = lastUsed
        self.expiresAt = expiresAt
        self.ipRestrictions = ipRestrictions
        self.metadata = metadata
    }
}

// MARK: - App Environment
enum AppEnvironment: String, CaseIterable {
    case sandbox = "sandbox"
    case production = "production"
    
    var displayName: String {
        switch self {
        case .sandbox: return "Test Environment"
        case .production: return "Production"
        }
    }
}

// All other models have been moved to their respective files:
// - User.swift
// - Transaction.swift
// - TimeRange, PaymentMethod, TransactionStatus, and TransactionType are defined in Transaction.swift
// - Other model files