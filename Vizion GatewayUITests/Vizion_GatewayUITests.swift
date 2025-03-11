//
//  Vizion_GatewayUITests.swift
//  Vizion GatewayUITests
//
//  Created by Andre Browne on 1/13/25.
//

import XCTest

final class Vizion_GatewayUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }
    
    // MARK: - Authentication Flow Tests
    
    func testLoginFlow() throws {
        // Given
        let emailTextField = app.textFields["email"]
        let passwordTextField = app.secureTextFields["password"]
        let loginButton = app.buttons["Sign In"]
        
        // When
        emailTextField.tap()
        emailTextField.typeText("test@example.com")
        
        passwordTextField.tap()
        passwordTextField.typeText("password123")
        
        loginButton.tap()
        
        // Then
        XCTAssertTrue(app.tabBars["Tab Bar"].exists)
        XCTAssertTrue(app.navigationBars["Dashboard"].exists)
    }
    
    func testSignUpFlow() throws {
        // Given
        let signUpButton = app.buttons["Sign Up"]
        signUpButton.tap()
        
        let firstNameTextField = app.textFields["firstName"]
        let lastNameTextField = app.textFields["lastName"]
        let emailTextField = app.textFields["email"]
        let passwordTextField = app.secureTextFields["password"]
        let confirmPasswordTextField = app.secureTextFields["confirmPassword"]
        let createAccountButton = app.buttons["Create Account"]
        
        // When
        firstNameTextField.tap()
        firstNameTextField.typeText("John")
        
        lastNameTextField.tap()
        lastNameTextField.typeText("Doe")
        
        emailTextField.tap()
        emailTextField.typeText("john.doe@example.com")
        
        passwordTextField.tap()
        passwordTextField.typeText("password123")
        
        confirmPasswordTextField.tap()
        confirmPasswordTextField.typeText("password123")
        
        createAccountButton.tap()
        
        // Then
        XCTAssertTrue(app.tabBars["Tab Bar"].exists)
        XCTAssertTrue(app.navigationBars["Dashboard"].exists)
    }
    
    // MARK: - Dashboard Tests
    
    func testDashboardLoads() throws {
        // Login first
        login()
        
        // Then
        XCTAssertTrue(app.staticTexts["Total Balance"].exists)
        XCTAssertTrue(app.staticTexts["Recent Transactions"].exists)
        XCTAssertTrue(app.staticTexts["Quick Actions"].exists)
    }
    
    func testTransactionList() throws {
        // Login first
        login()
        
        // Navigate to transactions
        app.tabBars["Tab Bar"].buttons["Transactions"].tap()
        
        // Then
        XCTAssertTrue(app.navigationBars["Transactions"].exists)
        XCTAssertTrue(app.tables["TransactionList"].exists)
    }
    
    // MARK: - Wallet Tests
    
    func testSendMoney() throws {
        // Login first
        login()
        
        // Navigate to Send Money
        app.tabBars["Tab Bar"].buttons["Send"].tap()
        
        // Fill in details
        let amountTextField = app.textFields["amount"]
        let recipientTextField = app.textFields["recipient"]
        let sendButton = app.buttons["Send"]
        
        amountTextField.tap()
        amountTextField.typeText("100")
        
        recipientTextField.tap()
        recipientTextField.typeText("recipient@example.com")
        
        sendButton.tap()
        
        // Then
        XCTAssertTrue(app.alerts["Success"].exists)
    }
    
    func testRequestMoney() throws {
        // Login first
        login()
        
        // Navigate to Request Money
        app.tabBars["Tab Bar"].buttons["Request"].tap()
        
        // Fill in details
        let amountTextField = app.textFields["amount"]
        let fromTextField = app.textFields["from"]
        let requestButton = app.buttons["Request"]
        
        amountTextField.tap()
        amountTextField.typeText("50")
        
        fromTextField.tap()
        fromTextField.typeText("payer@example.com")
        
        requestButton.tap()
        
        // Then
        XCTAssertTrue(app.alerts["Success"].exists)
    }
    
    // MARK: - Settings Tests
    
    func testProfileSettings() throws {
        // Login first
        login()
        
        // Navigate to Settings
        app.tabBars["Tab Bar"].buttons["Profile"].tap()
        
        // Tap Edit Profile
        app.buttons["Edit Profile"].tap()
        
        // Update profile
        let phoneTextField = app.textFields["phone"]
        phoneTextField.tap()
        phoneTextField.typeText("1234567890")
        
        app.buttons["Save"].tap()
        
        // Then
        XCTAssertTrue(app.alerts["Success"].exists)
    }
    
    func testSecuritySettings() throws {
        // Login first
        login()
        
        // Navigate to Settings
        app.tabBars["Tab Bar"].buttons["Profile"].tap()
        
        // Tap Security
        app.buttons["Security"].tap()
        
        // Toggle biometric authentication
        let biometricSwitch = app.switches["enableBiometric"]
        biometricSwitch.tap()
        
        // Then
        XCTAssertTrue(app.alerts["Biometric Setup"].exists)
    }
    
    // MARK: - Helper Methods
    
    private func login() {
        let emailTextField = app.textFields["email"]
        let passwordTextField = app.secureTextFields["password"]
        let loginButton = app.buttons["Sign In"]
        
        emailTextField.tap()
        emailTextField.typeText("test@example.com")
        
        passwordTextField.tap()
        passwordTextField.typeText("password123")
        
        loginButton.tap()
    }
}
