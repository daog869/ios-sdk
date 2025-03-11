# VizionGateway iOS SDK

A native iOS SDK for integrating with the Vizion Gateway payment processing platform, designed specifically for Caribbean businesses.

## Features

- Direct card payment processing
- Apple Pay integration
- Transaction management
- Webhook support
- Analytics and reporting

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/vizion-gateway/ios-sdk.git", from: "1.0.0")
]
```

Or in Xcode:
1. File > Add Packages
2. Enter: `https://github.com/vizion-gateway/ios-sdk.git`
3. Click "Add Package"

## Usage

### Initialize the SDK

```swift
import VizionGateway

// In your app's initialization code
VizionGateway.configure(
    .init(
        apiKey: "your_api_key",
        merchantId: "your_merchant_id",
        environment: .sandbox // or .production
    )
)
```

### Process a Card Payment

```swift
// Present the payment sheet
CardPaymentView(
    amount: 99.99,
    currency: .xcd,
    sourceId: "customer_id",
    destinationId: "merchant_id",
    orderId: "order123"
) { result in
    switch result.status {
    case .completed:
        print("Payment succeeded: \(result.transactionId)")
    case .failed:
        print("Payment failed: \(result.errorMessage ?? "Unknown error")")
    default:
        break
    }
}
```

### Handle Apple Pay

```swift
let handler = ApplePayHandler(
    amount: 99.99,
    sourceId: "customer_id",
    destinationId: "merchant_id",
    orderId: "order123"
)

handler.presentApplePay(in: viewController) { success in
    if success {
        print("Apple Pay payment completed!")
    } else {
        print("Apple Pay payment failed or cancelled")
    }
}
```

## Documentation

For detailed documentation, visit [https://docs.viziongateway.com](https://docs.viziongateway.com)

## Support

Need help? Contact us:
- Email: support@viziongateway.com
- Website: [https://viziongateway.com](https://viziongateway.com)

## License

This SDK is proprietary software. All rights reserved.

© 2024 Vizion Gateway Inc. 