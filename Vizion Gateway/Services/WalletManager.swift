import Foundation
import SwiftData
import Combine
import CryptoKit
import FirebaseAuth

// MARK: - Wallet Manager

class WalletManager {
    static let shared = WalletManager()
    
    private let modelContext: ModelContext
    private let notificationCenter = NotificationCenter.default
    private var cancellables = Set<AnyCancellable>()
    
    // Fee configuration
    private let defaultTransactionFeePercentage: Double = 0.025  // 2.5%
    private let defaultPlatformFeePercentage: Double = 0.01      // 1%
    private let defaultReservePercentage: Double = 0.10          // 10%
    
    private let securityManager = SecurityManager()
    
    // Publisher for balance changes
    private let balanceChangeSubject = PassthroughSubject<BalanceChangeNotification, Never>()
    var balanceChangePublisher: AnyPublisher<BalanceChangeNotification, Never> {
        balanceChangeSubject.eraseToAnyPublisher()
    }
    
    private init() {
        let container = try! ModelContainer(for: Wallet.self, WalletTransaction.self, WithdrawalRequest.self)
        self.modelContext = ModelContext(container)
        setupSettlementTimer()
    }
    
    // MARK: - Wallet Creation and Management
    
    func createWallet(for userId: String, type: WalletType, reservePercentage: Double? = nil) async throws -> Wallet {
        // Check if wallet already exists
        let descriptor = FetchDescriptor<Wallet>(predicate: #Predicate<Wallet> { wallet in 
            wallet.userId == userId && wallet.type == type 
        })
        let existingWallets = try modelContext.fetch(descriptor)
        
        if let existingWallet = existingWallets.first {
            return existingWallet
        }
        
        // Create new wallet
        let wallet = Wallet(
            userId: userId,
            type: type,
            reservePercentage: reservePercentage ?? defaultReservePercentage
        )
        
        modelContext.insert(wallet)
        try modelContext.save()
        
        return wallet
    }
    
    func getWallet(for userId: String, type: WalletType) async throws -> Wallet? {
        let descriptor = FetchDescriptor<Wallet>(predicate: #Predicate<Wallet> { wallet in 
            wallet.userId == userId && wallet.type == type 
        })
        let wallets = try modelContext.fetch(descriptor)
        return wallets.first
    }
    
    // MARK: - Transaction Processing
    
    /// Process a payment with automatic fee and reserve calculation
    func processPayment(
        amount: Double,
        currency: Currency,
        sourceId: String,
        sourceType: EntityType,
        destinationId: String,
        destinationType: EntityType,
        reference: String? = nil,
        description: String? = nil,
        metadata: [String: String]? = nil
    ) async throws -> WalletTransaction {
        // Validate amount
        guard amount > 0 else {
            throw WalletError.invalidAmount
        }
        
        // Get source wallet if internal entity
        var sourceWallet: Wallet?
        if sourceType == .user || sourceType == .merchant {
            sourceWallet = try await getWallet(for: sourceId, type: sourceType == .user ? .user : .merchant)
            
            // Verify source has sufficient funds
            guard let wallet = sourceWallet else {
                throw WalletError.walletNotFound
            }
            
            guard wallet.balance(for: currency) >= amount else {
                throw WalletError.insufficientFunds
            }
        }
        
        // Get destination wallet
        var destinationWallet: Wallet?
        if destinationType == .user || destinationType == .merchant {
            destinationWallet = try await getWallet(for: destinationId, type: destinationType == .user ? .user : .merchant)
            
            guard destinationWallet != nil else {
                throw WalletError.walletNotFound
            }
        }
        
        // Get platform wallet for fees
        let platformWallet = try await getPlatformWallet()
        
        // Calculate fees and reserve amount
        let merchantReservePercentage = (destinationWallet?.reservePercentage ?? defaultReservePercentage)
        let transactionFeePercentage = defaultTransactionFeePercentage
        let platformFeePercentage = defaultPlatformFeePercentage
        
        // Create transaction
        let transaction = WalletTransaction(
            type: .payment,
            amount: amount,
            currency: currency,
            sourceType: sourceType,
            sourceId: sourceId,
            destinationType: destinationType,
            destinationId: destinationId,
            reference: reference,
            description: description,
            metadata: metadata
        )
        
        // Calculate fees and reserves
        transaction.calculateAmounts(
            walletReservePercentage: merchantReservePercentage,
            feePercentage: transactionFeePercentage,
            platformFeePercentage: platformFeePercentage
        )
        
        // Process fund movements
        if let sourceWallet = sourceWallet {
            // Deduct full amount from source
            sourceWallet.updateBalance(currency: currency, amount: -amount)
            transaction.wallet = sourceWallet
        }
        
        if let destinationWallet = destinationWallet {
            // Add net amount to destination
            let netAmount = transaction.netAmount
            destinationWallet.updateBalance(currency: currency, amount: netAmount)
            
            // Set aside reserve amount
            if transaction.reserveAmount > 0 {
                destinationWallet.updateReserve(currency: currency, amount: transaction.reserveAmount)
            }
            
            // Notify destination of balance change
            notifyBalanceChange(
                userId: destinationId,
                walletType: destinationType == .user ? .user : .merchant,
                currency: currency,
                amount: netAmount,
                transactionType: .payment,
                transactionId: transaction.id
            )
        }
        
        // Add fees to platform wallet
        let totalFees = transaction.fee + transaction.platformFee
        if totalFees > 0 {
            platformWallet.updateBalance(currency: currency, amount: totalFees)
        }
        
        // Mark transaction as completed
        transaction.markCompleted()
        
        // Save changes
        modelContext.insert(transaction)
        try modelContext.save()
        
        return transaction
    }
    
    /// Process a deposit to a wallet
    func processDeposit(
        amount: Double,
        currency: Currency,
        destinationId: String,
        destinationType: EntityType,
        sourceType: EntityType = .external,
        sourceId: String = "external",
        reference: String? = nil,
        description: String? = nil,
        metadata: [String: String]? = nil
    ) async throws -> WalletTransaction {
        // Validate amount
        guard amount > 0 else {
            throw WalletError.invalidAmount
        }
        
        // Get destination wallet
        var destinationWallet: Wallet?
        if destinationType == .user || destinationType == .merchant {
            destinationWallet = try await getWallet(for: destinationId, type: destinationType == .user ? .user : .merchant)
            
            guard destinationWallet != nil else {
                throw WalletError.walletNotFound
            }
        } else {
            throw WalletError.invalidDestination
        }
        
        // Create transaction
        let transaction = WalletTransaction(
            type: .deposit,
            amount: amount,
            currency: currency,
            sourceType: sourceType,
            sourceId: sourceId,
            destinationType: destinationType,
            destinationId: destinationId,
            reference: reference,
            description: description,
            metadata: metadata
        )
        
        // Add funds to destination wallet
        if let wallet = destinationWallet {
            wallet.updateBalance(currency: currency, amount: amount)
            transaction.wallet = wallet
            
            // Notify destination of balance change
            notifyBalanceChange(
                userId: destinationId,
                walletType: destinationType == .user ? .user : .merchant,
                currency: currency,
                amount: amount,
                transactionType: .deposit,
                transactionId: transaction.id
            )
        }
        
        // Mark transaction as completed
        transaction.markCompleted()
        
        // Save changes
        modelContext.insert(transaction)
        try modelContext.save()
        
        return transaction
    }
    
    /// Process a withdrawal from a wallet
    func processWithdrawal(
        request: WithdrawalRequest
    ) async throws -> WalletTransaction {
        // Validate request status
        guard request.status == .approved else {
            throw WalletError.withdrawalNotApproved
        }
        
        // Get source wallet
        let merchantWallet = try await getWallet(for: request.userId, type: .merchant)
        let userWallet = try await getWallet(for: request.userId, type: .user)
        guard let wallet = merchantWallet ?? userWallet else {
            throw WalletError.walletNotFound
        }
        
        // Verify sufficient available funds
        guard wallet.availableBalance(for: request.currency) >= request.amount else {
            throw WalletError.insufficientFunds
        }
        
        // Create transaction
        let transaction = WalletTransaction(
            type: .withdrawal,
            amount: request.amount,
            currency: request.currency,
            sourceType: wallet.type == .user ? .user : .merchant,
            sourceId: wallet.userId,
            destinationType: .bank,
            destinationId: request.destinationDetails["accountId"] ?? "unknown",
            reference: request.id,
            description: "Withdrawal to \(request.destinationType.rawValue)"
        )
        
        // Deduct funds from wallet
        wallet.updateBalance(currency: request.currency, amount: -request.amount)
        transaction.wallet = wallet
        
        // Mark transaction as completed
        transaction.markCompleted()
        
        // Update withdrawal request
        request.complete(transactionId: transaction.id)
        
        // Notify of balance change
        notifyBalanceChange(
            userId: wallet.userId,
            walletType: wallet.type,
            currency: request.currency,
            amount: -request.amount,
            transactionType: .withdrawal,
            transactionId: transaction.id
        )
        
        // Save changes
        modelContext.insert(transaction)
        try modelContext.save()
        
        return transaction
    }
    
    /// Create a withdrawal request
    func createWithdrawalRequest(
        userId: String,
        amount: Double,
        currency: Currency,
        destinationType: WithdrawalDestination,
        destinationDetails: [String: String]
    ) async throws -> WithdrawalRequest {
        // Validate amount
        guard amount > 0 else {
            throw WalletError.invalidAmount
        }
        
        // Get wallet
        let merchantWallet = try await getWallet(for: userId, type: .merchant)
        let userWallet = try await getWallet(for: userId, type: .user)
        guard let wallet = merchantWallet ?? userWallet else {
            throw WalletError.walletNotFound
        }
        
        // Verify sufficient available funds
        guard wallet.availableBalance(for: currency) >= amount else {
            throw WalletError.insufficientFunds
        }
        
        // Create withdrawal request
        let request = WithdrawalRequest(
            userId: userId,
            amount: amount,
            currency: currency,
            destinationType: destinationType,
            destinationDetails: destinationDetails
        )
        
        request.wallet = wallet
        
        // Save request
        modelContext.insert(request)
        try modelContext.save()
        
        return request
    }
    
    /// Review and approve/reject a withdrawal request
    func reviewWithdrawalRequest(id: String, approve: Bool, rejectionReason: String? = nil) async throws -> WithdrawalRequest {
        // Find the request
        let descriptor = FetchDescriptor<WithdrawalRequest>(predicate: #Predicate<WithdrawalRequest> { withdrawalRequest in 
            withdrawalRequest.id == id 
        })
        guard let request = try modelContext.fetch(descriptor).first else {
            throw WalletError.withdrawalRequestNotFound
        }
        
        // Update request status
        if approve {
            request.approve()
        } else {
            guard let reason = rejectionReason else {
                throw WalletError.rejectionReasonRequired
            }
            request.reject(reason: reason)
        }
        
        try modelContext.save()
        return request
    }
    
    // MARK: - Settlement Processing
    
    /// Process settlement for a merchant
    func processSettlement(for merchantId: String) async throws -> WalletTransaction? {
        // Get merchant wallet
        guard let wallet = try await getWallet(for: merchantId, type: .merchant) else {
            throw WalletError.walletNotFound
        }
        
        // Check if there's a balance to settle
        var hasBalance = false
        for balance in wallet.balances {
            if wallet.availableBalance(for: balance.currency) > 0 {
                hasBalance = true
                break
            }
        }
        
        if !hasBalance {
            return nil
        }
        
        // Process settlement for each currency
        var settlementTransactions: [WalletTransaction] = []
        
        for balance in wallet.balances {
            let availableBalance = wallet.availableBalance(for: balance.currency)
            
            if availableBalance > 0 {
                // Create settlement transaction
                let transaction = WalletTransaction(
                    type: .settlement,
                    amount: availableBalance,
                    currency: balance.currency,
                    sourceType: .merchant,
                    sourceId: merchantId,
                    destinationType: .bank,
                    destinationId: "merchant_bank_account", // This would come from merchant settings
                    description: "Automatic settlement"
                )
                
                // Deduct funds from wallet
                wallet.updateBalance(currency: balance.currency, amount: -availableBalance)
                transaction.wallet = wallet
                
                // Mark as completed
                transaction.markCompleted()
                
                // Add to list
                settlementTransactions.append(transaction)
                
                // Notify of balance change
                notifyBalanceChange(
                    userId: wallet.userId,
                    walletType: wallet.type,
                    currency: balance.currency,
                    amount: -availableBalance,
                    transactionType: .settlement,
                    transactionId: transaction.id
                )
                
                // Save transaction
                modelContext.insert(transaction)
            }
        }
        
        // Update next settlement date
        wallet.nextSettlementDate = calculateNextSettlementDateForWallet(wallet)
        
        try modelContext.save()
        
        // Return the first transaction or nil if none were created
        return settlementTransactions.first
    }
    
    /// Check and process all scheduled settlements
    private func processScheduledSettlements() async {
        do {
            // Get all wallets with auto-settlement enabled and due for settlement
            let now = Date()
            let descriptor = FetchDescriptor<Wallet>(
                predicate: #Predicate<Wallet> { wallet in
                    wallet.autoSettlement == true &&
                    wallet.nextSettlementDate != nil &&
                    wallet.nextSettlementDate! <= now &&
                    wallet.type == .merchant
                }
            )
            
            let walletsToSettle = try modelContext.fetch(descriptor)
            
            for wallet in walletsToSettle {
                do {
                    // Process settlement for this wallet
                    _ = try await processSettlement(for: wallet.userId)
                } catch {
                    print("Error settling wallet \(wallet.id): \(error.localizedDescription)")
                    // Continue with next wallet
                }
            }
        } catch {
            print("Error processing scheduled settlements: \(error.localizedDescription)")
        }
    }
    
    private func setupSettlementTimer() {
        // Set up a timer to check for settlements every hour
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.processScheduledSettlements()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Reserve Management
    
    /// Release reserve amount back to available balance
    func releaseReserve(
        merchantId: String,
        amount: Double,
        currency: Currency
    ) async throws -> WalletTransaction {
        // Get merchant wallet
        guard let wallet = try await getWallet(for: merchantId, type: .merchant) else {
            throw WalletError.walletNotFound
        }
        
        // Check if there's enough in reserve
        guard wallet.reserve(for: currency) >= amount else {
            throw WalletError.insufficientReserve
        }
        
        // Create transaction for reserve release
        let transaction = WalletTransaction(
            type: .reserveRelease,
            amount: amount,
            currency: currency,
            sourceType: .platform,
            sourceId: "system",
            destinationType: .merchant,
            destinationId: merchantId,
            description: "Reserve release"
        )
        
        // Update reserve amount
        wallet.updateReserve(currency: currency, amount: -amount)
        transaction.wallet = wallet
        
        // Mark as completed
        transaction.markCompleted()
        
        // Save changes
        modelContext.insert(transaction)
        try modelContext.save()
        
        return transaction
    }
    
    // MARK: - Platform Wallet
    
    /// Get or create the platform wallet
    private func getPlatformWallet() async throws -> Wallet {
        let platformId = "platform"
        
        if let existingWallet = try await getWallet(for: platformId, type: .platform) {
            return existingWallet
        }
        
        // Create platform wallet if it doesn't exist
        return try await createWallet(for: platformId, type: .platform, reservePercentage: 0)
    }
    
    // MARK: - Notifications
    
    /// Notify about balance changes
    private func notifyBalanceChange(
        userId: String,
        walletType: WalletType,
        currency: Currency,
        amount: Double,
        transactionType: WalletTransactionType,
        transactionId: String
    ) {
        let notification = BalanceChangeNotification(
            userId: userId,
            walletType: walletType,
            currency: currency,
            amountChanged: amount,
            transactionType: transactionType,
            transactionId: transactionId,
            timestamp: Date()
        )
        
        // Publish to subscribers
        balanceChangeSubject.send(notification)
        
        // Post notification
        NotificationCenter.default.post(
            name: .walletBalanceChanged,
            object: notification
        )
    }
    
    // MARK: - Multi-Currency Support
    
    /// Convert amount between currencies
    func convertCurrency(
        amount: Double,
        from sourceCurrency: Currency,
        to targetCurrency: Currency
    ) async throws -> (amount: Double, exchangeRate: Double) {
        // In a real app, you would fetch live exchange rates from an API
        // For now, we'll use some fixed rates for demonstration
        let rates: [Currency: [Currency: Double]] = [
            .xcd: [.usd: 0.37, .eur: 0.34, .gbp: 0.29],
            .usd: [.xcd: 2.70, .eur: 0.92, .gbp: 0.79],
            .eur: [.xcd: 2.94, .usd: 1.09, .gbp: 0.86],
            .gbp: [.xcd: 3.45, .usd: 1.27, .eur: 1.16]
        ]
        
        // If same currency, no conversion needed
        if sourceCurrency == targetCurrency {
            return (amount, 1.0)
        }
        
        // Get exchange rate
        guard let sourceRates = rates[sourceCurrency],
              let exchangeRate = sourceRates[targetCurrency] else {
            throw WalletError.currencyConversionNotAvailable
        }
        
        // Calculate converted amount
        let convertedAmount = amount * exchangeRate
        
        return (convertedAmount, exchangeRate)
    }
    
    // Helper method to calculate the next settlement date for a wallet
    private func calculateNextSettlementDateForWallet(_ wallet: Wallet) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch wallet.settlementFrequency {
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
}

// MARK: - Supporting Types

struct BalanceChangeNotification {
    let userId: String
    let walletType: WalletType
    let currency: Currency
    let amountChanged: Double
    let transactionType: WalletTransactionType
    let transactionId: String
    let timestamp: Date
}

// Notification name extension
extension Notification.Name {
    static let walletBalanceChanged = Notification.Name("walletBalanceChanged")
}

// Error types
enum WalletError: Error {
    case invalidAmount
    case insufficientFunds
    case walletNotFound
    case withdrawalRequestNotFound
    case withdrawalNotApproved
    case rejectionReasonRequired
    case invalidDestination
    case insufficientReserve
    case currencyConversionNotAvailable
    case encryptionError
    case securityError
}

// MARK: - Security Manager

class SecurityManager {
    // Encrypt sensitive data
    func encrypt(_ data: Data) throws -> Data {
        let key = SymmetricKey(size: .bits256)
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }
    
    // Decrypt sensitive data
    func decrypt(_ data: Data, with key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // Generate a random API key
    func generateAPIKey() -> String {
        let keyLength = 32
        var bytes = [UInt8](repeating: 0, count: keyLength)
        _ = SecRandomCopyBytes(kSecRandomDefault, keyLength, &bytes)
        return Data(bytes).base64EncodedString()
    }
} 