import Foundation
import SwiftData

@Model
final class Wallet: Identifiable {
    var id: String
    var userId: String
    var type: WalletType
    var createdAt: Date
    var updatedAt: Date
    var status: WalletStatus
    var balances: [CurrencyBalance]
    var reserves: [CurrencyReserve]
    
    // Settings
    var reservePercentage: Double
    var dailyWithdrawalLimit: Double?
    var monthlyTransactionLimit: Double?
    var autoSettlement: Bool
    var settlementFrequency: SettlementFrequency
    var nextSettlementDate: Date?
    
    // Relationships - will be handled by SwiftData
    @Relationship(deleteRule: .cascade, inverse: \WalletTransaction.wallet)
    var transactions: [WalletTransaction] = []
    
    @Relationship(deleteRule: .cascade, inverse: \WithdrawalRequest.wallet)
    var withdrawalRequests: [WithdrawalRequest] = []
    
    init(id: String = UUID().uuidString,
         userId: String,
         type: WalletType,
         status: WalletStatus = .active,
         reservePercentage: Double = 0.10,
         autoSettlement: Bool = true,
         settlementFrequency: SettlementFrequency = .weekly) {
        self.id = id
        self.userId = userId
        self.type = type
        self.createdAt = Date()
        self.updatedAt = Date()
        self.status = status
        self.balances = []
        self.reserves = []
        self.reservePercentage = reservePercentage
        self.autoSettlement = autoSettlement
        self.settlementFrequency = settlementFrequency
        
        // Set next settlement date based on frequency
        if autoSettlement {
            self.nextSettlementDate = calculateNextSettlementDate()
        }
    }
    
    // Get balance for a specific currency
    func balance(for currency: Currency) -> Double {
        balances.first(where: { $0.currency == currency })?.amount ?? 0.0
    }
    
    // Get reserve for a specific currency
    func reserve(for currency: Currency) -> Double {
        reserves.first(where: { $0.currency == currency })?.amount ?? 0.0
    }
    
    // Get available balance (total balance minus reserve)
    func availableBalance(for currency: Currency) -> Double {
        balance(for: currency) - reserve(for: currency)
    }
    
    // Calculate next settlement date based on frequency
    private func calculateNextSettlementDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch settlementFrequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: now) ?? now
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: now) ?? now
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: now) ?? now
        }
    }
    
    // Update balance for a specific currency
    func updateBalance(currency: Currency, amount: Double) {
        if let index = balances.firstIndex(where: { $0.currency == currency }) {
            balances[index].amount += amount
        } else {
            balances.append(CurrencyBalance(currency: currency, amount: amount))
        }
        updatedAt = Date()
    }
    
    // Update reserve for a specific currency
    func updateReserve(currency: Currency, amount: Double) {
        if let index = reserves.firstIndex(where: { $0.currency == currency }) {
            reserves[index].amount += amount
        } else {
            reserves.append(CurrencyReserve(currency: currency, amount: amount))
        }
        updatedAt = Date()
    }
}

// Supporting Types
enum WalletType: String, Codable {
    case user
    case merchant
    case platform
}

enum WalletStatus: String, Codable {
    case pending
    case active
    case suspended
    case closed
}

enum SettlementFrequency: String, Codable {
    case daily
    case weekly
    case biweekly
    case monthly
}

enum Currency: String, Codable, CaseIterable {
    case xcd = "XCD"
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    
    var symbol: String {
        switch self {
        case .xcd: return "EC$"
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        }
    }
}

// Balance for each currency
struct CurrencyBalance: Codable, Hashable {
    var currency: Currency
    var amount: Double
}

// Reserve for each currency
struct CurrencyReserve: Codable, Hashable {
    var currency: Currency
    var amount: Double
    var releaseDate: Date?
} 