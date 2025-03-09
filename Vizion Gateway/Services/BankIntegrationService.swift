import Foundation
import SwiftData

enum BankError: Error {
    case invalidAmount
    case insufficientFunds
    case accountNotFound
    case connectionError
    case processingError
    case invalidCredentials
    case timeout
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .invalidAmount:
            return "Invalid transaction amount"
        case .insufficientFunds:
            return "Insufficient funds"
        case .accountNotFound:
            return "Account not found"
        case .connectionError:
            return "Bank connection error"
        case .processingError:
            return "Transaction processing error"
        case .invalidCredentials:
            return "Invalid bank credentials"
        case .timeout:
            return "Bank request timeout"
        case .unknown:
            return "Unknown bank error"
        }
    }
}

@Observable
class BankIntegrationService {
    static let shared = BankIntegrationService()
    
    private(set) var isConnected = false
    private(set) var lastSync: Date?
    private(set) var processingError: BankError?
    
    private var apiKey: String?
    private var bankCredentials: [String: String] = [:]
    private var webhookURL: String?
    
    // MARK: - Configuration
    
    func configure(apiKey: String, webhookURL: String) {
        self.apiKey = apiKey
        self.webhookURL = webhookURL
    }
    
    func addBankCredentials(bankId: String, credentials: [String: String]) {
        bankCredentials[bankId] = credentials.values.joined(separator: ":")
    }
    
    // MARK: - Connection Management
    
    func connect() async throws {
        guard let apiKey = apiKey else {
            throw BankError.invalidCredentials
        }
        
        // Simulate bank connection
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        if Bool.random() {
            isConnected = true
            processingError = nil
        } else {
            throw BankError.connectionError
        }
    }
    
    func disconnect() {
        isConnected = false
        lastSync = nil
    }
    
    // MARK: - Transaction Processing
    
    func processTransaction(_ transaction: Transaction) async throws {
        guard isConnected else {
            throw BankError.connectionError
        }
        
        // Validate amount
        guard transaction.amount > 0 else {
            throw BankError.invalidAmount
        }
        
        // Simulate processing delay
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Simulate random success/failure
        let success = Double.random(in: 0...1) > 0.1
        if success {
            transaction.status = .completed
        } else {
            transaction.status = .failed
            throw BankError.processingError
        }
    }
    
    func processRefund(_ transaction: Transaction) async throws {
        guard isConnected else {
            throw BankError.connectionError
        }
        
        guard transaction.status == .completed else {
            throw BankError.processingError
        }
        
        // Simulate processing delay
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Create refund transaction
        let refund = Transaction(
            amount: transaction.amount,
            merchantName: transaction.merchantName,
            customerID: transaction.customerID,
            type: .refund,
            paymentMethod: transaction.paymentMethod,
            description: "Refund for \(transaction.reference ?? "No reference")"
        )
        
        // Simulate random success/failure
        let success = Double.random(in: 0...1) > 0.1
        if success {
            transaction.status = .refunded
            refund.status = .completed
        } else {
            refund.status = .failed
            throw BankError.processingError
        }
    }
    
    // MARK: - Settlement
    
    func processSettlement(transactions: [Transaction]) async throws -> String {
        guard isConnected else {
            throw BankError.connectionError
        }
        
        // Validate transactions
        guard !transactions.isEmpty else {
            throw BankError.processingError
        }
        
        // Calculate total amount
        let totalAmount = transactions.reduce(0) { $0 + $1.amount }
        
        // Simulate processing delay
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Generate settlement reference
        let reference = "STL-\(UUID().uuidString.prefix(8))"
        
        // Simulate random success/failure
        let success = Double.random(in: 0...1) > 0.1
        if !success {
            throw BankError.processingError
        }
        
        return reference
    }
    
    // MARK: - Sync
    
    func syncTransactions() async throws {
        guard isConnected else {
            throw BankError.connectionError
        }
        
        // Simulate sync delay
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        lastSync = Date()
    }
    
    // MARK: - Webhooks
    
    func registerWebhook() async throws {
        guard let webhookURL = webhookURL else {
            throw BankError.processingError
        }
        
        // Simulate registration delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Simulate random success/failure
        if Double.random(in: 0...1) > 0.1 {
            // Webhook registered
        } else {
            throw BankError.processingError
        }
    }
    
    func handleWebhook(_ data: Data) throws {
        // Parse webhook data
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BankError.processingError
        }
        
        // Process webhook event
        // This would handle various webhook events from the bank
    }
} 