import XCTest
@testable import Vizion_Gateway

final class WalletManagerTests: XCTestCase {
    var walletManager: WalletManager!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        super.setUp()
        let container = try ModelContainer(for: Wallet.self, WalletTransaction.self, WithdrawalRequest.self)
        modelContext = ModelContext(container)
        walletManager = WalletManager.shared
    }
    
    override func tearDownWithError() throws {
        modelContext = nil
        walletManager = nil
        super.tearDown()
    }
    
    // MARK: - Wallet Creation Tests
    
    func testCreateWallet() async throws {
        // Given
        let userId = UUID().uuidString
        let type = WalletType.user
        
        // When
        let wallet = try await walletManager.createWallet(for: userId, type: type)
        
        // Then
        XCTAssertNotNil(wallet)
        XCTAssertEqual(wallet.userId, userId)
        XCTAssertEqual(wallet.type, type)
        XCTAssertEqual(wallet.balances.count, 0)
    }
    
    func testCreateDuplicateWallet() async throws {
        // Given
        let userId = UUID().uuidString
        let type = WalletType.user
        
        // When
        let firstWallet = try await walletManager.createWallet(for: userId, type: type)
        let secondWallet = try await walletManager.createWallet(for: userId, type: type)
        
        // Then
        XCTAssertEqual(firstWallet.id, secondWallet.id)
    }
    
    // MARK: - Transaction Tests
    
    func testProcessPayment() async throws {
        // Given
        let sourceId = UUID().uuidString
        let destinationId = UUID().uuidString
        let amount: Double = 100.0
        let currency = Currency.usd
        
        // Create source wallet with funds
        let sourceWallet = try await walletManager.createWallet(for: sourceId, type: .user)
        try await walletManager.processDeposit(
            amount: amount,
            currency: currency,
            destinationId: sourceId,
            destinationType: .user
        )
        
        // When
        let transaction = try await walletManager.processPayment(
            amount: amount,
            currency: currency,
            sourceId: sourceId,
            sourceType: .user,
            destinationId: destinationId,
            destinationType: .merchant
        )
        
        // Then
        XCTAssertNotNil(transaction)
        XCTAssertEqual(transaction.amount, amount)
        XCTAssertEqual(transaction.currency, currency)
        XCTAssertEqual(transaction.sourceId, sourceId)
        XCTAssertEqual(transaction.destinationId, destinationId)
        XCTAssertEqual(transaction.status, .completed)
    }
    
    func testInsufficientFundsPayment() async throws {
        // Given
        let sourceId = UUID().uuidString
        let destinationId = UUID().uuidString
        let amount: Double = 100.0
        let currency = Currency.usd
        
        // Create source wallet without funds
        _ = try await walletManager.createWallet(for: sourceId, type: .user)
        
        // When/Then
        await XCTAssertThrowsError(try await walletManager.processPayment(
            amount: amount,
            currency: currency,
            sourceId: sourceId,
            sourceType: .user,
            destinationId: destinationId,
            destinationType: .merchant
        )) { error in
            XCTAssertEqual(error as? WalletError, WalletError.insufficientFunds)
        }
    }
    
    // MARK: - Withdrawal Tests
    
    func testCreateWithdrawalRequest() async throws {
        // Given
        let userId = UUID().uuidString
        let amount: Double = 100.0
        let currency = Currency.usd
        
        // Create wallet with funds
        let wallet = try await walletManager.createWallet(for: userId, type: .merchant)
        try await walletManager.processDeposit(
            amount: amount,
            currency: currency,
            destinationId: userId,
            destinationType: .merchant
        )
        
        // When
        let request = try await walletManager.createWithdrawalRequest(
            userId: userId,
            amount: amount,
            currency: currency,
            destinationType: .bank,
            destinationDetails: ["accountId": "test_account"]
        )
        
        // Then
        XCTAssertNotNil(request)
        XCTAssertEqual(request.userId, userId)
        XCTAssertEqual(request.amount, amount)
        XCTAssertEqual(request.currency, currency)
        XCTAssertEqual(request.status, .pending)
    }
    
    func testProcessWithdrawal() async throws {
        // Given
        let userId = UUID().uuidString
        let amount: Double = 100.0
        let currency = Currency.usd
        
        // Create wallet with funds
        let wallet = try await walletManager.createWallet(for: userId, type: .merchant)
        try await walletManager.processDeposit(
            amount: amount,
            currency: currency,
            destinationId: userId,
            destinationType: .merchant
        )
        
        // Create and approve withdrawal request
        let request = try await walletManager.createWithdrawalRequest(
            userId: userId,
            amount: amount,
            currency: currency,
            destinationType: .bank,
            destinationDetails: ["accountId": "test_account"]
        )
        
        try await walletManager.reviewWithdrawalRequest(id: request.id, approve: true)
        
        // When
        let transaction = try await walletManager.processWithdrawal(request: request)
        
        // Then
        XCTAssertNotNil(transaction)
        XCTAssertEqual(transaction.amount, amount)
        XCTAssertEqual(transaction.currency, currency)
        XCTAssertEqual(transaction.sourceId, userId)
        XCTAssertEqual(transaction.type, .withdrawal)
        XCTAssertEqual(transaction.status, .completed)
    }
    
    // MARK: - Helper Methods
    
    private func await<T>(_ expression: @autoclosure () async throws -> T) async throws -> T {
        try await expression()
    }
    
    private func XCTAssertThrowsError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error but no error was thrown", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
} 