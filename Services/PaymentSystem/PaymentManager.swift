import Foundation
import SwiftData

class PaymentManager {
    static let shared = PaymentManager()
    private let modelContext: ModelContext
    private var providers: [PaymentProviderType: PaymentProvider] = [:]
    private let analyticsManager = AnalyticsManager.shared
    private let webhookManager = WebhookManager.shared
    
    private init() {
        let container = try! ModelContainer(for: PaymentTransaction.self)
        self.modelContext = ModelContext(container)
        setupProviders()
    }
    
    // MARK: - Provider Setup
    
    private func setupProviders() {
        // Initialize payment providers
        providers[.stripe] = StripeProvider()
        providers[.paypal] = PayPalProvider()
        providers[.square] = SquareProvider()
        providers[.applePay] = ApplePayProvider()
    }
    
    // MARK: - Payment Processing
    
    func processPayment(
        amount: Decimal,
        currency: Currency,
        method: PaymentMethod,
        sourceId: String,
        destinationId: String,
        metadata: [String: String]? = nil
    ) async throws -> PaymentResult {
        // Validate amount
        guard amount > 0 else {
            throw PaymentError.invalidAmount
        }
        
        // Create transaction
        let transaction = PaymentTransaction(
            amount: amount,
            currency: currency,
            type: .charge,
            method: method,
            sourceId: sourceId,
            destinationId: destinationId,
            metadata: metadata
        )
        
        // Get appropriate provider
        let provider = try getProvider(for: method)
        
        // Start analytics tracking
        let startTime = Date()
        
        do {
            // Process payment
            transaction.status = .processing
            modelContext.insert(transaction)
            try modelContext.save()
            
            // Process with provider
            let result = try await provider.processPayment(transaction)
            
            // Update transaction
            transaction.status = result.status
            transaction.metadata = result.metadata
            transaction.errorMessage = result.errorMessage
            if result.status == .completed {
                transaction.completedAt = Date()
            }
            try modelContext.save()
            
            // Track analytics
            trackPaymentAnalytics(
                transaction: transaction,
                provider: provider.type,
                startTime: startTime,
                success: result.status == .completed
            )
            
            // Send webhook
            sendPaymentWebhook(transaction: transaction, result: result)
            
            return result
        } catch {
            // Handle failure
            transaction.status = .failed
            transaction.errorMessage = error.localizedDescription
            try? modelContext.save()
            
            // Track failed analytics
            trackPaymentAnalytics(
                transaction: transaction,
                provider: provider.type,
                startTime: startTime,
                success: false,
                error: error
            )
            
            throw error
        }
    }
    
    // MARK: - Refunds
    
    func refundPayment(
        transactionId: String,
        amount: Decimal? = nil
    ) async throws -> PaymentResult {
        // Find transaction
        let descriptor = FetchDescriptor<PaymentTransaction>(
            predicate: #Predicate<PaymentTransaction> { transaction in
                transaction.id == transactionId
            }
        )
        
        guard let transaction = try modelContext.fetch(descriptor).first else {
            throw PaymentError.transactionNotFound
        }
        
        // Validate refund
        guard transaction.status == .completed else {
            throw PaymentError.refundNotAllowed
        }
        
        // Create refund transaction
        let refundTransaction = PaymentTransaction(
            amount: amount ?? transaction.amount,
            currency: transaction.currency,
            type: .refund,
            method: transaction.method,
            sourceId: transaction.destinationId,
            destinationId: transaction.sourceId,
            metadata: ["original_transaction": transaction.id]
        )
        
        // Get provider
        let provider = try getProvider(for: transaction.method)
        
        // Process refund
        let startTime = Date()
        
        do {
            refundTransaction.status = .processing
            modelContext.insert(refundTransaction)
            try modelContext.save()
            
            let result = try await provider.refundPayment(transaction, amount: amount)
            
            refundTransaction.status = result.status
            refundTransaction.metadata = result.metadata
            refundTransaction.errorMessage = result.errorMessage
            if result.status == .completed {
                refundTransaction.completedAt = Date()
                transaction.status = .refunded
            }
            try modelContext.save()
            
            // Track analytics
            trackPaymentAnalytics(
                transaction: refundTransaction,
                provider: provider.type,
                startTime: startTime,
                success: result.status == .completed
            )
            
            // Send webhook
            sendPaymentWebhook(transaction: refundTransaction, result: result)
            
            return result
        } catch {
            refundTransaction.status = .failed
            refundTransaction.errorMessage = error.localizedDescription
            try? modelContext.save()
            
            // Track failed analytics
            trackPaymentAnalytics(
                transaction: refundTransaction,
                provider: provider.type,
                startTime: startTime,
                success: false,
                error: error
            )
            
            throw error
        }
    }
    
    // MARK: - Transaction Management
    
    func getTransaction(_ id: String) throws -> PaymentTransaction {
        let descriptor = FetchDescriptor<PaymentTransaction>(
            predicate: #Predicate<PaymentTransaction> { transaction in
                transaction.id == id
            }
        )
        
        guard let transaction = try modelContext.fetch(descriptor).first else {
            throw PaymentError.transactionNotFound
        }
        
        return transaction
    }
    
    func getTransactions(
        for userId: String,
        type: PaymentType? = nil,
        status: PaymentStatus? = nil,
        from: Date? = nil,
        to: Date? = nil
    ) throws -> [PaymentTransaction] {
        var predicate = #Predicate<PaymentTransaction> { transaction in
            transaction.sourceId == userId || transaction.destinationId == userId
        }
        
        if let type = type {
            predicate = predicate && #Predicate<PaymentTransaction> { transaction in
                transaction.type == type
            }
        }
        
        if let status = status {
            predicate = predicate && #Predicate<PaymentTransaction> { transaction in
                transaction.status == status
            }
        }
        
        if let from = from {
            predicate = predicate && #Predicate<PaymentTransaction> { transaction in
                transaction.createdAt >= from
            }
        }
        
        if let to = to {
            predicate = predicate && #Predicate<PaymentTransaction> { transaction in
                transaction.createdAt <= to
            }
        }
        
        let descriptor = FetchDescriptor<PaymentTransaction>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Helper Methods
    
    private func getProvider(for method: PaymentMethod) throws -> PaymentProvider {
        let providerType: PaymentProviderType
        
        switch method {
        case .card:
            providerType = .stripe
        case .applePay:
            providerType = .applePay
        case .bankTransfer:
            providerType = .paypal
        case .wallet:
            providerType = .square
        }
        
        guard let provider = providers[providerType] else {
            throw PaymentError.invalidPaymentMethod
        }
        
        return provider
    }
    
    private func trackPaymentAnalytics(
        transaction: PaymentTransaction,
        provider: PaymentProviderType,
        startTime: Date,
        success: Bool,
        error: Error? = nil
    ) {
        let analytics = PaymentAnalytics(
            transactionId: transaction.id,
            amount: transaction.amount,
            currency: transaction.currency,
            method: transaction.method,
            provider: provider,
            processingTime: Date().timeIntervalSince(startTime),
            success: success,
            errorType: error?.localizedDescription,
            metadata: transaction.metadata
        )
        
        analyticsManager.logEvent(
            success ? .transactionCompleted : .transactionFailed,
            parameters: [
                "transaction_id": analytics.transactionId,
                "amount": "\(analytics.amount)",
                "currency": analytics.currency.rawValue,
                "method": analytics.method.rawValue,
                "provider": analytics.provider.rawValue,
                "processing_time": analytics.processingTime,
                "success": analytics.success,
                "error_type": analytics.errorType ?? "none"
            ]
        )
    }
    
    private func sendPaymentWebhook(
        transaction: PaymentTransaction,
        result: PaymentResult
    ) {
        let event: PaymentWebhookEvent
        switch (transaction.type, result.status) {
        case (.charge, .completed):
            event = .paymentSucceeded
        case (.charge, .failed):
            event = .paymentFailed
        case (.refund, .completed):
            event = .refundProcessed
        case (.refund, .failed):
            event = .refundFailed
        default:
            return
        }
        
        let payload: [String: Any] = [
            "transaction_id": transaction.id,
            "amount": "\(transaction.amount)",
            "currency": transaction.currency.rawValue,
            "status": result.status.rawValue,
            "type": transaction.type.rawValue,
            "method": transaction.method.rawValue,
            "source_id": transaction.sourceId,
            "destination_id": transaction.destinationId,
            "provider_reference": result.providerReference ?? "",
            "error_message": result.errorMessage ?? "",
            "metadata": transaction.metadata ?? [:]
        ]
        
        webhookManager.deliverWebhook(
            event: .transactionCompleted,
            businessId: transaction.destinationId,
            payload: payload
        )
    }
} 