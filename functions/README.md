# Vizion Gateway Firebase Functions

This directory contains the Firebase Cloud Functions for the Vizion Gateway payment processing platform.

## Overview

These functions provide the backend API for the Vizion Gateway payment processing platform, including:

- Payment processing
- Transaction reporting
- Webhook management
- Merchant onboarding

## Setup

### Prerequisites

- Node.js 18 (required by Firebase Functions)
- Firebase CLI (`npm install -g firebase-tools`)
- Service account key file in the project root (`vizion-gateway-firebase-adminsdk-fbsvc-cfe0acf447.json`)

### Installation

1. Install dependencies:
   ```bash
   cd functions
   npm install
   ```

### Local Development with Emulators

1. Start the Firebase emulators:
   ```bash
   firebase emulators:start
   ```

2. Access the emulator dashboard at http://localhost:4001

### iOS Integration

To use these functions from your iOS app:

1. Ensure you have the required Firebase iOS SDK dependencies in your Xcode project.
2. Use the `FirebaseFunctionService.swift` class to interact with the functions.
3. For local development, set the environment variable:
   ```swift
   // In your app delegate or test code
   ProcessInfo.processInfo.setValue("localhost", forKey: "FUNCTIONS_EMULATOR_HOST")
   ```

## Available Functions

### processPayment

Process a payment transaction with detailed information.

```swift
FirebaseFunctionService.shared.processPayment(
    amount: 100.0,
    currency: "USD",
    merchantId: "mer_123456789",
    apiKey: "vz_abcdef12345",
    completion: { result in
        switch result {
        case .success(let response):
            print("Transaction successful: \(response.transactionId)")
        case .failure(let error):
            print("Error: \(error.localizedDescription)")
        }
    }
)
```

### generateReport

Generate a transaction report for a specified date range.

```swift
FirebaseFunctionService.shared.generateReport(
    merchantId: "mer_123456789",
    apiKey: "vz_abcdef12345",
    reportType: "transactions",
    startDate: Date().addingTimeInterval(-7*24*60*60), // 7 days ago
    endDate: Date(),
    completion: { result in
        switch result {
        case .success(let response):
            print("Report available at: \(response.downloadUrl)")
        case .failure(let error):
            print("Error: \(error.localizedDescription)")
        }
    }
)
```

### getTransactionStatistics

Get statistics about transactions for a specific time period.

```swift
FirebaseFunctionService.shared.getTransactionStatistics(
    merchantId: "mer_123456789",
    apiKey: "vz_abcdef12345",
    timeframe: "last7days",
    completion: { result in
        switch result {
        case .success(let response):
            print("Total volume: \(response.totalVolume)")
            print("Transaction count: \(response.transactionCount)")
        case .failure(let error):
            print("Error: \(error.localizedDescription)")
        }
    }
)
```

### triggerWebhook

Test webhook delivery to a specified URL.

```swift
FirebaseFunctionService.shared.triggerWebhook(
    merchantId: "mer_123456789",
    apiKey: "vz_abcdef12345",
    webhookUrl: "https://example.com/webhook",
    eventType: "payment.completed",
    completion: { result in
        switch result {
        case .success(let response):
            print("Webhook triggered: \(response.webhookId)")
        case .failure(let error):
            print("Error: \(error.localizedDescription)")
        }
    }
)
```

### onboardMerchant

Create a new merchant account with initial configuration.

```swift
FirebaseFunctionService.shared.onboardMerchant(
    businessName: "Example Business",
    email: "contact@example.com",
    contactName: "John Doe",
    address: "123 Main St, Anytown, USA",
    completion: { result in
        switch result {
        case .success(let response):
            print("Merchant created: \(response.merchantId)")
            print("API Key: \(response.apiKey.key)")
        case .failure(let error):
            print("Error: \(error.localizedDescription)")
        }
    }
)
```

## Deployment

To deploy the functions to Firebase:

```bash
firebase deploy --only functions
```

To deploy a specific function:

```bash
firebase deploy --only functions:processPayment
```

## Environment Variables

For production, you can set these environment variables:

- `FIREBASE_SERVICE_ACCOUNT`: JSON service account credentials (as string)
- `STORAGE_BUCKET`: Firebase Storage bucket name

## Troubleshooting

- **Error: "Could not load the default credentials"** - Make sure the service account key file is in the correct location.
- **Error: "Function failed on loading user code"** - Check the Firebase logs for syntax errors.
- **Error: "Port already in use"** - Stop any running emulator instances. 