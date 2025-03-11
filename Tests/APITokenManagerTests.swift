import XCTest
@testable import Vizion_Gateway

final class APITokenManagerTests: XCTestCase {
    var tokenManager: APITokenManager!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        super.setUp()
        let container = try ModelContainer(for: APIToken.self)
        modelContext = ModelContext(container)
        tokenManager = APITokenManager.shared
    }
    
    override func tearDownWithError() throws {
        modelContext = nil
        tokenManager = nil
        super.tearDown()
    }
    
    // MARK: - Token Generation Tests
    
    func testGenerateToken() {
        // When
        let token1 = APITokenManager.generateToken()
        let token2 = APITokenManager.generateToken()
        
        // Then
        XCTAssertNotNil(token1)
        XCTAssertNotNil(token2)
        XCTAssertNotEqual(token1, token2, "Generated tokens should be unique")
        XCTAssertFalse(token1.contains("+"), "Token should not contain '+'")
        XCTAssertFalse(token1.contains("/"), "Token should not contain '/'")
        XCTAssertFalse(token1.contains("="), "Token should not contain '='")
    }
    
    // MARK: - Token Creation Tests
    
    func testCreateToken() async throws {
        // Given
        let businessId = "test_business"
        let name = "Test Token"
        let scopes: [APIScope] = [.read, .transactions]
        
        // When
        let token = try await tokenManager.createToken(
            businessId: businessId,
            name: name,
            scopes: scopes
        )
        
        // Then
        XCTAssertEqual(token.businessId, businessId)
        XCTAssertEqual(token.name, name)
        XCTAssertEqual(token.scopes, scopes)
        XCTAssertTrue(token.isActive)
        XCTAssertNil(token.expiresAt)
        XCTAssertNil(token.lastUsedAt)
    }
    
    func testCreateTokenWithOptions() async throws {
        // Given
        let businessId = "test_business"
        let name = "Test Token"
        let scopes: [APIScope] = [.read, .transactions]
        let ipRestrictions = ["192.168.1.1"]
        let webhookUrl = "https://api.test.com/webhook"
        let expiresAt = Date().addingTimeInterval(3600)
        
        // When
        let token = try await tokenManager.createToken(
            businessId: businessId,
            name: name,
            scopes: scopes,
            ipRestrictions: ipRestrictions,
            webhookUrl: webhookUrl,
            expiresAt: expiresAt
        )
        
        // Then
        XCTAssertEqual(token.ipRestrictions, ipRestrictions)
        XCTAssertEqual(token.webhookUrl, webhookUrl)
        XCTAssertEqual(token.expiresAt?.timeIntervalRounded(to: 60),
                      expiresAt.timeIntervalRounded(to: 60))
    }
    
    // MARK: - Token Validation Tests
    
    func testValidateValidToken() async throws {
        // Given
        let token = try await tokenManager.createToken(
            businessId: "test_business",
            name: "Test Token",
            scopes: [.read, .transactions]
        )
        
        // When
        let validatedToken = try await tokenManager.validateToken(
            token.token,
            requiredScopes: [.read]
        )
        
        // Then
        XCTAssertEqual(validatedToken.id, token.id)
        XCTAssertNotNil(validatedToken.lastUsedAt)
    }
    
    func testValidateExpiredToken() async throws {
        // Given
        let expiresAt = Date().addingTimeInterval(-3600) // 1 hour ago
        let token = try await tokenManager.createToken(
            businessId: "test_business",
            name: "Test Token",
            scopes: [.read],
            expiresAt: expiresAt
        )
        
        // When/Then
        await XCTAssertThrowsError(
            try await tokenManager.validateToken(token.token, requiredScopes: [.read])
        ) { error in
            XCTAssertEqual(error as? APIError, .tokenExpired)
        }
    }
    
    func testValidateTokenWithInsufficientScopes() async throws {
        // Given
        let token = try await tokenManager.createToken(
            businessId: "test_business",
            name: "Test Token",
            scopes: [.read]
        )
        
        // When/Then
        await XCTAssertThrowsError(
            try await tokenManager.validateToken(token.token, requiredScopes: [.write])
        ) { error in
            XCTAssertEqual(error as? APIError, .insufficientScopes)
        }
    }
    
    func testValidateTokenWithIPRestriction() async throws {
        // Given
        let token = try await tokenManager.createToken(
            businessId: "test_business",
            name: "Test Token",
            scopes: [.read],
            ipRestrictions: ["192.168.1.1"]
        )
        
        // When/Then
        await XCTAssertThrowsError(
            try await tokenManager.validateToken(
                token.token,
                requiredScopes: [.read],
                ipAddress: "192.168.1.2"
            )
        ) { error in
            XCTAssertEqual(error as? APIError, .ipNotAllowed)
        }
    }
    
    // MARK: - Token Management Tests
    
    func testRevokeToken() async throws {
        // Given
        let token = try await tokenManager.createToken(
            businessId: "test_business",
            name: "Test Token",
            scopes: [.read]
        )
        
        // When
        try await tokenManager.revokeToken(token)
        
        // Then
        await XCTAssertThrowsError(
            try await tokenManager.validateToken(token.token, requiredScopes: [.read])
        ) { error in
            XCTAssertEqual(error as? APIError, .invalidToken)
        }
    }
    
    func testGetTokensForBusiness() async throws {
        // Given
        let businessId = "test_business"
        try await tokenManager.createToken(
            businessId: businessId,
            name: "Token 1",
            scopes: [.read]
        )
        try await tokenManager.createToken(
            businessId: businessId,
            name: "Token 2",
            scopes: [.write]
        )
        
        // When
        let tokens = try await tokenManager.getTokens(for: businessId)
        
        // Then
        XCTAssertEqual(tokens.count, 2)
        XCTAssertTrue(tokens.allSatisfy { $0.businessId == businessId })
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

extension Date {
    func timeIntervalRounded(to minutes: TimeInterval) -> TimeInterval {
        return (timeIntervalSince1970 / minutes).rounded() * minutes
    }
} 