# Vizion Gateway iOS SDK

A Swift SDK for integrating with the Vizion Gateway payment processing platform.

## Features

- Process payments using credit/debit cards
- Apple Pay integration
- Unified payment sheet interface
- Type-safe API with modern Swift features
- Comprehensive error handling
- iOS 17+ compatibility

## Installation

### Swift Package Manager

Add the following dependency to your Package.swift file:

```swift
dependencies: [
    .package(url: "https://github.com/daog869/ios-sdk.git", from: "1.0.0")
]
```

Or add it directly via Xcode:
1. File > Add Packages...
2. Enter the repository URL: https://github.com/daog869/ios-sdk.git
3. Click "Add Package"

## Usage

### Initialize the SDK

```swift
import VizionGateway

// Initialize with your API key
VizionGateway.shared.initialize(apiKey: "your_api_key_here", environment: .production)
```

### Process a Payment

```swift
// Using the Payment Sheet (recommended)
let paymentSheet = PaymentSheet(
    amount: 99.99,
    currency: .xcd,
    sourceId: "customer_id",
    destinationId: "merchant_id",
    orderId: "order123"
) { result in
    switch result.status {
    case .completed:
        print("Payment completed successfully!")
    case .failed:
        print("Payment failed: \(result.errorMessage ?? "Unknown error")")
    default:
        print("Payment status: \(result.status)")
    }
}

// Present the payment sheet
let hostingController = UIHostingController(rootView: paymentSheet)
presentingViewController.present(hostingController, animated: true)
```

### Using Apple Pay

```swift
// Check if Apple Pay is available
let (canMakePayments, hasCards) = ApplePayHandler.applePayStatus()

if canMakePayments && hasCards {
    // Create the Apple Pay handler
    let applePayHandler = ApplePayHandler(
        amount: 99.99,
        sourceId: "customer_id",
        destinationId: "merchant_id",
        orderId: "order123"
    )
    
    // Present Apple Pay
    applePayHandler.presentApplePay(in: viewController) { success in
        if success {
            print("Apple Pay payment completed!")
        } else {
            print("Apple Pay payment failed or canceled")
        }
    }
}
```

## Documentation

For detailed documentation, please refer to the inline code comments or contact Vizion Gateway support.

## Requirements

- iOS 15.0+
- Swift 5.5+
- Xcode 14.0+

## License

This SDK is proprietary and confidential. Unauthorized use is prohibited.
