# Vizion Gateway Integration Guide

This guide explains how to integrate Chef Reloaded and other client applications with the Vizion Gateway payment processing system.

## Overview

Vizion Gateway provides native payment processing for Caribbean businesses. This guide focuses on integrating direct card payments into your checkout flow.

## Prerequisites

- API credentials for Vizion Gateway
- iOS app built with SwiftUI or UIKit
- Xcode 15.0+
- Swift 5.9+

## Installation

### Swift Package Manager (Recommended)

Add the SDK to your project using Swift Package Manager:

1. In Xcode, select File > Add Packages...
2. Enter the package URL: `https://github.com/daog869/ios-sdk.git`
3. Click "Add Package"

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/daog869/ios-sdk.git", from: "1.0.0")
]
```

## Usage

1. Import the SDK:
```swift
import VizionGateway
```

2. Initialize the SDK:
```swift
VizionGateway.configure(
    .init(
        apiKey: "your_api_key",
        merchantId: "your_merchant_id",
        environment: .sandbox // Use .production for live environment
    )
)
```

## Integration Steps

### 1. Add Dependencies

Add Vizion Gateway SDK to your app using Swift Package Manager:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/daog869/ios-sdk.git", from: "1.0.0")
]
```

### 2. Configure API Credentials

Initialize the SDK with your API credentials:

```swift
import VizionGateway

func configurePayments() {
    VizionGateway.configure(
        apiKey: "your_api_key",
        environment: .production, // or .sandbox for testing
        merchantID: "your_merchant_id"
    )
}
```

Add this to your app's initialization code (e.g., in your `AppDelegate` or `App` struct).

### 3. Implement Card Payment Flow

#### Option 1: Use Provided UI Components

The simplest approach is to use our pre-built UI components:

```swift
import SwiftUI
import VizionGateway

struct CheckoutView: View {
    @State private var isShowingPaymentSheet = false
    let orderAmount: Decimal = 125.50
    let orderId = "order123"
    
    var body: some View {
        VStack {
            // Your order summary
            
            Button("Pay with Card") {
                isShowingPaymentSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $isShowingPaymentSheet) {
            CardPaymentView(
                amount: orderAmount,
                currency: .xcd,
                sourceId: "customer_id", // Your customer ID
                destinationId: "your_merchant_id", // Your merchant ID
                orderId: orderId
            ) { result in
                // Handle payment result
                if result.status == .completed {
                    // Payment succeeded
                    print("Payment succeeded: \(result.transactionId)")
                } else {
                    // Payment failed
                    print("Payment failed: \(result.errorMessage ?? "Unknown error")")
                }
            }
        }
    }
}
```

#### Option 2: Build Your Own UI

If you prefer to create your own payment form:

```swift
import VizionGateway

class PaymentViewModel: ObservableObject {
    private let paymentManager = VizionGateway.paymentManager
    
    func processPayment(
        cardNumber: String,
        expiryMonth: Int,
        expiryYear: Int,
        cvv: String,
        amount: Decimal,
        currency: Currency = .xcd,
        metadata: [String: String]? = nil
    ) async throws -> PaymentResult {
        let cardDetails: [String: String] = [
            "card_number": cardNumber,
            "expiry_month": String(expiryMonth),
            "expiry_year": String(expiryYear),
            "cvv": cvv
        ]
        
        var combinedMetadata = metadata ?? [:]
        combinedMetadata["card_details"] = try JSONEncoder().encode(cardDetails).base64EncodedString()
        
        return try await paymentManager.processPayment(
            amount: amount,
            currency: currency,
            method: .card,
            sourceId: VizionGateway.customerId, // Customer ID
            destinationId: VizionGateway.merchantId, // Your merchant ID
            metadata: combinedMetadata
        )
    }
}
```

### 4. Handle Payment Responses

Process the payment result:

```swift
switch result.status {
case .completed:
    // Payment succeeded
    showSuccessUI(transactionId: result.transactionId)
    
case .failed:
    // Payment failed
    showErrorUI(message: result.errorMessage ?? "Payment failed")
    
case .pending:
    // Payment is processing
    showProcessingUI()
    
default:
    // Other statuses
    handleOtherStatus(result.status)
}
```

### 5. Implement Webhooks (Server-side)

Set up webhook endpoints on your server to receive payment notifications:

```swift
// Your server endpoint
app.post("/webhooks/vizion-gateway") { req -> Response in
    // Verify webhook signature
    guard let signature = req.headers["X-Vizion-Signature"].first,
          VizionGateway.verifyWebhookSignature(payload: req.body, signature: signature) else {
        return Response(status: .unauthorized)
    }
    
    // Process the event
    let event = try req.content.decode(WebhookEvent.self)
    
    switch event.type {
    case "payment.succeeded":
        // Handle successful payment
        let transactionId = event.data["transaction_id"] as? String ?? ""
        // Update order status, send confirmation email, etc.
        
    case "payment.failed":
        // Handle failed payment
        let transactionId = event.data["transaction_id"] as? String ?? ""
        let errorMessage = event.data["error_message"] as? String ?? "Unknown error"
        // Notify user, update order status, etc.
        
    default:
        print("Unhandled event type: \(event.type)")
    }
    
    return Response(status: .ok)
}
```

## Testing

For testing integration without processing real payments:

1. Use the sandbox environment:
```swift
VizionGateway.configure(
    apiKey: "your_sandbox_api_key",
    environment: .sandbox,
    merchantId: "your_merchant_id"
)
```

2. Test cards:
   - Successful payment: `4242 4242 4242 4242`
   - Failed payment: `4000 0000 0000 0002`

## Security Considerations

- Never store raw card data on your servers
- Use HTTPS for all API communication
- Keep your API credentials secure
- Follow PCI-DSS guidelines for handling payment data
- Consider implementing tokenization for improved security

## Support

For integration assistance:
- Email: support@viziongateway.com
- Documentation: https://docs.viziongateway.com
- API Reference: https://api.viziongateway.com/docs 