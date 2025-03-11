import XCTest
@testable import Vizion_Gateway

final class WebhookManagerTests: XCTestCase {
    var webhookManager: WebhookManager!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        super.setUp()
        let container = try ModelContainer(for: WebhookEndpoint.self)
        modelContext = ModelContext(container)
        webhookManager = WebhookManager.shared
    }
    
    override func tearDownWithError() throws {
        modelContext = nil
        webhookManager = nil
        super.tearDown()
    }
    
    // MARK: - Secret Generation Tests
    
    func testGenerateSecret() {
        // When
        let secret1 = WebhookManager.generateSecret()
        let secret2 = WebhookManager.generateSecret()
        
        // Then
        XCTAssertNotNil(secret1)
        XCTAssertNotNil(secret2)
        XCTAssertNotEqual(secret1, secret2, "Generated secrets should be unique")
    }
    
    // MARK: - Endpoint Creation Tests
    
    func testCreateEndpoint() async throws {
        // Given
        let businessId = "test_business"
        let url = "https://api.test.com/webhook"
        let events: [WebhookEvent] = [.transactionCompleted, .walletUpdated]
        
        // When
        let endpoint = try await webhookManager.createEndpoint(
            businessId: businessId,
            url: url,
            events: events
        )
        
        // Then
        XCTAssertEqual(endpoint.businessId, businessId)
        XCTAssertEqual(endpoint.url, url)
        XCTAssertEqual(endpoint.events, events)
        XCTAssertTrue(endpoint.isActive)
        XCTAssertEqual(endpoint.failureCount, 0)
        XCTAssertEqual(endpoint.retryCount, 0)
        XCTAssertNotNil(endpoint.secret)
    }
    
    // MARK: - Endpoint Management Tests
    
    func testGetEndpoints() async throws {
        // Given
        let businessId = "test_business"
        try await webhookManager.createEndpoint(
            businessId: businessId,
            url: "https://api.test.com/webhook1",
            events: [.transactionCompleted]
        )
        try await webhookManager.createEndpoint(
            businessId: businessId,
            url: "https://api.test.com/webhook2",
            events: [.walletUpdated]
        )
        
        // When
        let endpoints = try await webhookManager.getEndpoints(for: businessId)
        
        // Then
        XCTAssertEqual(endpoints.count, 2)
        XCTAssertTrue(endpoints.allSatisfy { $0.businessId == businessId })
    }
    
    // MARK: - Webhook Delivery Tests
    
    func testDeliverWebhook() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Webhook delivery")
        let businessId = "test_business"
        let endpoint = try await webhookManager.createEndpoint(
            businessId: businessId,
            url: "https://api.test.com/webhook",
            events: [.transactionCompleted]
        )
        
        // Create a mock URLSession
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        URLSession.shared = URLSession(configuration: config)
        
        // Configure mock response
        MockURLProtocol.requestHandler = { request in
            // Verify request headers
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertNotNil(request.value(forHTTPHeaderField: "X-Vizion-Signature"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Vizion-Event"), WebhookEvent.transactionCompleted.rawValue)
            
            // Verify payload
            let payload = try JSONSerialization.jsonObject(with: request.httpBody!, options: []) as? [String: Any]
            XCTAssertNotNil(payload?["event"])
            XCTAssertNotNil(payload?["timestamp"])
            XCTAssertEqual(payload?["test_key"] as? String, "test_value")
            
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        
        // When
        webhookManager.deliverWebhook(
            event: .transactionCompleted,
            businessId: businessId,
            payload: ["test_key": "test_value"]
        )
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Signature Verification Tests
    
    func testVerifySignature() throws {
        // Given
        let secret = "test_secret"
        let payload = """
        {
            "event": "transaction.completed",
            "test_key": "test_value"
        }
        """.data(using: .utf8)!
        
        // When
        let signature = webhookManager.generateSignature(for: payload, secret: secret)
        let isValid = webhookManager.verifySignature(
            payload: payload,
            signature: "sha256=\(signature)",
            secret: secret
        )
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testVerifyInvalidSignature() throws {
        // Given
        let secret = "test_secret"
        let payload = """
        {
            "event": "transaction.completed",
            "test_key": "test_value"
        }
        """.data(using: .utf8)!
        
        // When
        let isValid = webhookManager.verifySignature(
            payload: payload,
            signature: "sha256=invalid_signature",
            secret: secret
        )
        
        // Then
        XCTAssertFalse(isValid)
    }
}

// MARK: - Mock URL Protocol

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Handler is unavailable.")
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
} 