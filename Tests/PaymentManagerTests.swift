import XCTest
@testable import Vizion_Gateway

final class PaymentManagerTests: XCTestCase {
    var paymentManager: PaymentManager!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        super.setUp()
        let container = try ModelContainer(for: PaymentTransaction.self)
        modelContext = ModelContext(container)
        paymentManager = PaymentManager.shared
    }
    
    override func tearDownWithError() throws {
        modelContext = nil
        paymentManager = nil
        super.tearDown()
    }
    
    // MARK: - Payment Processing Tests
    
    func testProcessPayment() async throws {
        // Given
        let amount: Decimal = 100.0
        let currency: Currency = .usd
        let method: PaymentMethod = .card
        let sourceId = "user_123"
        let destinationId = "merchant_456"
        
        // When
        let result = try await paymentManager.processPayment(
            amount: amount,
            currency: currency,
            method: method,
            sourceId: sourceId,
            destinationId: destinationId
        )
        
        // Then
        XCTAssertEqual(result.status, .completed)
        XCTAssertNotNil(result.transactionId)
        
        // Verify transaction was saved
        let transaction = try paymentManager.getTransaction(result.transactionId)
        XCTAssertEqual(transaction.amount, amount)
        XCTAssertEqual(transaction.currency, currency)
        XCTAssertEqual(transaction.method, method)
        XCTAssertEqual(transaction.sourceId, sourceId)
        XCTAssertEqual(transaction.destinationId, destinationId)
        XCTAssertEqual(transaction.status, .completed)
        XCTAssertNotNil(transaction.completedAt)
    }
    
    func testProcessPaymentWithInvalidAmount() async {
        // When/Then
        await XCTAssertThrowsError(
            try await paymentManager.processPayment(
                amount: -100.0,
                currency: .usd,
                method: .card,
                sourceId: "user_123",
                destinationId: "merchant_456"
            )
        ) { error in
            XCTAssertEqual(error as? PaymentError, .invalidAmount)
        }
    }
    
    // MARK: - Refund Tests
    
    func testRefundPayment() async throws {
        // Given
        let payment = try await paymentManager.processPayment(
            amount: 100.0,
            currency: .usd,
            method: .card,
            sourceId: "user_123",
            destinationId: "merchant_456"
        )
        
        // When
        let refund = try await paymentManager.refundPayment(
            transactionId: payment.transactionId,
            amount: 50.0
        )
        
        // Then
        XCTAssertEqual(refund.status, .completed)
        XCTAssertNotNil(refund.transactionId)
        
        // Verify refund transaction
        let refundTransaction = try paymentManager.getTransaction(refund.transactionId)
        XCTAssertEqual(refundTransaction.amount, 50.0)
        XCTAssertEqual(refundTransaction.type, .refund)
        XCTAssertEqual(refundTransaction.status, .completed)
        XCTAssertEqual(refundTransaction.sourceId, "merchant_456")
        XCTAssertEqual(refundTransaction.destinationId, "user_123")
        
        // Verify original transaction was updated
        let originalTransaction = try paymentManager.getTransaction(payment.transactionId)
        XCTAssertEqual(originalTransaction.status, .refunded)
    }
    
    func testRefundNonexistentTransaction() async {
        // When/Then
        await XCTAssertThrowsError(
            try await paymentManager.refundPayment(
                transactionId: "nonexistent_id"
            )
        ) { error in
            XCTAssertEqual(error as? PaymentError, .transactionNotFound)
        }
    }
    
    func testRefundFailedTransaction() async throws {
        // Given
        let payment = try await paymentManager.processPayment(
            amount: 100.0,
            currency: .usd,
            method: .card,
            sourceId: "user_123",
            destinationId: "merchant_456"
        )
        
        let transaction = try paymentManager.getTransaction(payment.transactionId)
        transaction.status = .failed
        try modelContext.save()
        
        // When/Then
        await XCTAssertThrowsError(
            try await paymentManager.refundPayment(
                transactionId: payment.transactionId
            )
        ) { error in
            XCTAssertEqual(error as? PaymentError, .refundNotAllowed)
        }
    }
    
    // MARK: - Transaction Query Tests
    
    func testGetTransactions() async throws {
        // Given
        let userId = "user_123"
        
        // Create some transactions
        try await paymentManager.processPayment(
            amount: 100.0,
            currency: .usd,
            method: .card,
            sourceId: userId,
            destinationId: "merchant_1"
        )
        
        try await paymentManager.processPayment(
            amount: 200.0,
            currency: .eur,
            method: .bankTransfer,
            sourceId: "merchant_2",
            destinationId: userId
        )
        
        // When
        let transactions = try paymentManager.getTransactions(for: userId)
        
        // Then
        XCTAssertEqual(transactions.count, 2)
        XCTAssertTrue(transactions.allSatisfy { 
            $0.sourceId == userId || $0.destinationId == userId
        })
    }
    
    func testGetTransactionsWithFilters() async throws {
        // Given
        let userId = "user_123"
        let startDate = Date()
        
        try await paymentManager.processPayment(
            amount: 100.0,
            currency: .usd,
            method: .card,
            sourceId: userId,
            destinationId: "merchant_1"
        )
        
        // When
        let transactions = try paymentManager.getTransactions(
            for: userId,
            type: .charge,
            status: .completed,
            from: startDate,
            to: Date()
        )
        
        // Then
        XCTAssertFalse(transactions.isEmpty)
        XCTAssertTrue(transactions.allSatisfy {
            $0.type == .charge &&
            $0.status == .completed &&
            $0.createdAt >= startDate
        })
    }
    
    // MARK: - Helper Methods
    
    private func XCTAssertThrowsError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail(message(), file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
} 