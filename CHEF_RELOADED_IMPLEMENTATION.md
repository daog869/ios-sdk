# Chef Reloaded - Vizion Gateway Implementation

This guide provides Chef Reloaded-specific implementation details for integrating with Vizion Gateway payment processing.

## Overview

Chef Reloaded will implement both direct card payments and Apple Pay support using Vizion Gateway as the payment processor. This document outlines the code changes and integration points.

## Implementation Steps

### 1. Add Vizion Gateway SDK

Update your `Package.swift` file:

```swift
// Package.swift
dependencies: [
    // existing dependencies
    .package(url: "https://github.com/vizion-gateway/ios-sdk.git", from: "1.0.0")
]
```

### 2. Configure API Credentials

Add this to your `ChefReloadedApp.swift` file:

```swift
import SwiftUI
import VizionGateway

@main
struct ChefReloadedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Vizion Gateway
        VizionGateway.configure(
            apiKey: "your_api_key", 
            environment: .production,
            merchantID: "chef_reloaded_merchant"
        )
        return true
    }
}
```

### 3. Update Checkout View

Modify your existing `CheckoutView.swift` to support both payment methods:

```swift
import SwiftUI
import VizionGateway
import PassKit

struct CheckoutView: View {
    @StateObject private var viewModel = CheckoutViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let order: Order // Your existing Order model
    
    // Payment sheet state
    @State private var isShowingCardPayment = false
    @State private var isProcessingApplePay = false
    
    // Apple Pay availability check
    private var isApplePayAvailable: Bool {
        return PKPaymentAuthorizationViewController.canMakePayments()
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Order summary (your existing code)
                OrderSummaryView(order: order)
                
                // Payment options
                Section {
                    Text("Payment Method")
                        .font(.headline)
                    
                    // Card payment button
                    Button {
                        isShowingCardPayment = true
                    } label: {
                        HStack {
                            Image(systemName: "creditcard")
                            Text("Pay with Card")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    
                    // Apple Pay button (if available)
                    if isApplePayAvailable {
                        Button {
                            processApplePayment()
                        } label: {
                            HStack {
                                Image(systemName: "apple.logo")
                                    .imageScale(.medium)
                                Text("Pay with Apple Pay")
                                if isProcessingApplePay {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isProcessingApplePay)
                    }
                }
                .padding(.vertical)
            }
            .padding()
        }
        .navigationTitle("Checkout")
        .sheet(isPresented: $isShowingCardPayment) {
            // Present card payment view from Vizion Gateway SDK
            CardPaymentView(
                amount: order.totalAmount,
                currency: .xcd,
                sourceId: viewModel.currentUserId,
                destinationId: order.restaurantId,
                orderId: order.id
            ) { result in
                handlePaymentResult(result)
            }
        }
        .alert("Payment Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // Handle Apple Pay
    private func processApplePayment() {
        isProcessingApplePay = true
        
        // Create Apple Pay handler
        let applePayHandler = ApplePayHandler(
            amount: order.totalAmount,
            sourceId: viewModel.currentUserId,
            destinationId: order.restaurantId,
            orderId: order.id,
            metadata: [
                "app": "chef_reloaded",
                "items_count": "\(order.items.count)",
                "customer_name": viewModel.customerName
            ]
        )
        
        // Get the root view controller
        guard let rootVC = UIApplication.shared.windows.first?.rootViewController else {
            isProcessingApplePay = false
            viewModel.showError(message: "Cannot process Apple Pay at this time")
            return
        }
        
        // Present Apple Pay sheet
        applePayHandler.presentApplePay(in: rootVC) { success in
            isProcessingApplePay = false
            
            if success {
                // Payment succeeded
                DispatchQueue.main.async {
                    viewModel.completeOrder()
                    showOrderConfirmation()
                }
            } else {
                // Payment failed or cancelled
                DispatchQueue.main.async {
                    viewModel.showError(message: "Apple Pay payment was not completed")
                }
            }
        }
    }
    
    // Handle payment result
    private func handlePaymentResult(_ result: PaymentResult) {
        switch result.status {
        case .completed:
            viewModel.completeOrder()
            showOrderConfirmation()
            
        case .failed:
            viewModel.showError(message: result.errorMessage ?? "Payment failed")
            
        default:
            viewModel.showError(message: "Unexpected payment status: \(result.status.rawValue)")
        }
    }
    
    // Navigate to order confirmation
    private func showOrderConfirmation() {
        dismiss() // Dismiss checkout view
        
        // You'd typically navigate to an order confirmation screen here
        // This depends on your app's navigation structure
    }
}

// Your existing CheckoutViewModel with additions
class CheckoutViewModel: ObservableObject {
    @Published var showError = false
    @Published var errorMessage = ""
    
    var currentUserId: String {
        return UserManager.shared.currentUser?.id ?? "guest_user"
    }
    
    var customerName: String {
        return UserManager.shared.currentUser?.fullName ?? "Guest"
    }
    
    func showError(message: String) {
        self.errorMessage = message
        self.showError = true
    }
    
    func completeOrder() {
        // Your existing order completion logic
        // Update order status in database, etc.
    }
}
```

### 4. Update Info.plist

Add Apple Pay capability:

```xml
<key>PKPaymentNetworks</key>
<array>
    <string>visa</string>
    <string>mastercard</string>
    <string>amex</string>
    <string>discover</string>
</array>
```

### 5. Set Up Webhook Handler (Server-side)

On your Chef Reloaded backend:

```javascript
// Express.js example
const express = require('express');
const bodyParser = require('body-parser');
const crypto = require('crypto');
const app = express();

app.use(bodyParser.json());

// Webhook secret from Vizion Gateway 
const webhookSecret = process.env.VIZION_GATEWAY_WEBHOOK_SECRET;

// Verify webhook signature
function verifySignature(payload, signature) {
  const hmac = crypto.createHmac('sha256', webhookSecret);
  const digest = hmac.update(JSON.stringify(payload)).digest('hex');
  return crypto.timingSafeEqual(
    Buffer.from(digest),
    Buffer.from(signature)
  );
}

app.post('/webhooks/vizion-gateway', (req, res) => {
  const signature = req.headers['x-vizion-signature'];
  
  // Verify signature
  if (!signature || !verifySignature(req.body, signature)) {
    return res.status(401).send('Invalid signature');
  }
  
  const event = req.body;
  
  // Process the event
  switch (event.type) {
    case 'payment.succeeded':
      // Update order status to paid
      const orderId = event.data.metadata?.order_id;
      if (orderId) {
        // Update your database
        updateOrderStatus(orderId, 'paid');
        
        // Notify restaurant about new order
        notifyRestaurant(orderId);
      }
      break;
      
    case 'payment.failed':
      // Handle failed payment
      const failedOrderId = event.data.metadata?.order_id;
      if (failedOrderId) {
        updateOrderStatus(failedOrderId, 'payment_failed');
        // Maybe notify the user via push notification
      }
      break;
      
    default:
      console.log(`Unhandled event type: ${event.type}`);
  }
  
  res.status(200).send('Webhook received');
});

function updateOrderStatus(orderId, status) {
  // Your code to update order status in database
  console.log(`Updating order ${orderId} to ${status}`);
}

function notifyRestaurant(orderId) {
  // Your code to notify restaurant about new order
  console.log(`Notifying restaurant about order ${orderId}`);
}

app.listen(3000, () => {
  console.log('Webhook server listening on port 3000');
});
```

## Testing

1. **Test Environment**:
   Use the Vizion Gateway sandbox environment during development:

   ```swift
   VizionGateway.configure(
       apiKey: "your_sandbox_api_key",
       environment: .sandbox,
       merchantID: "chef_reloaded_merchant"
   )
   ```

2. **Test Cards**:
   - Success: `4242 4242 4242 4242`
   - Decline: `4000 0000 0000 0002`
   - Insufficient Funds: `4000 0000 0000 9995`

3. **Apple Pay Testing**:
   - Use the Apple Pay sandbox environment
   - Add test cards to your iOS Wallet for testing

## Deployment Checklist

Before going live:

1. Switch to production API keys
2. Verify PCI compliance requirements
3. Test the full payment flow in a staging environment
4. Set up proper error handling and logging
5. Configure production webhooks
6. Implement analytics for payment tracking
7. Set up monitoring for payment processing

## Support

For implementation assistance:
- Contact your Vizion Gateway account manager
- Email: support@viziongateway.com
- API documentation: https://docs.viziongateway.com 