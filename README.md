# Vizion Gateway

Vizion Gateway is a payment processing platform that facilitates transactions for merchants in St. Kitts and Nevis, allowing them to send and receive payments in Eastern Caribbean Dollars (XCD).

## Features

- Process payments using multiple payment methods
- Monitor transactions in real-time
- Generate reports and analytics
- Manage merchants and API keys
- Handle webhooks for integrations
- Support both sandbox and production environments

## Setup Instructions

### Prerequisites

- Xcode 15+
- iOS 17+
- Node.js 18+ (for Firebase Functions)
- Firebase CLI

### iOS App Setup

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/vizion-gateway.git
   cd vizion-gateway
   ```

2. Open the project in Xcode:
   ```
   open "Vizion Gateway.xcodeproj"
   ```

3. Add Firebase SDK using Swift Package Manager:
   - In Xcode, go to File > Add Packages...
   - Paste the Firebase iOS SDK URL: `https://github.com/firebase/firebase-ios-sdk.git`
   - Select the following packages:
     - FirebaseCore
     - FirebaseAuth
     - FirebaseFirestore
     - FirebaseStorage
     - FirebaseFunctions

4. Replace the placeholder `GoogleService-Info.plist` with your own from the Firebase Console.

5. Build and run the app.

### Firebase Setup

1. Create a Firebase project (if not already done):
   - Go to the [Firebase Console](https://console.firebase.google.com/)
   - Click "Add project" and follow the setup instructions

2. Deploy Firestore security rules:
   ```
   firebase deploy --only firestore:rules
   ```

3. Deploy Storage security rules:
   ```
   firebase deploy --only storage:rules
   ```

4. Set up and deploy Firebase Functions:
   ```
   cd functions
   npm install
   firebase deploy --only functions
   ```

## Environment Configuration

The app supports two environments:

- **Sandbox**: For development and testing. All transactions are simulated.
- **Production**: For real transactions.

You can switch between environments using the environment selector in the app's sidebar.

## Firebase Functions

The project includes the following Firebase Functions:

- `processPayment`: Processes a payment transaction
- `generateReport`: Generates a transaction report
- `getTransactionStatistics`: Calculates transaction statistics
- `triggerWebhook`: Tests webhook delivery
- `onboardMerchant`: Onboards a new merchant

## Security Rules

Security rules are configured for both Firestore and Storage to ensure proper access control:

- Users can only access data in their current environment
- Different permission levels based on user roles
- Special permissions for merchants and administrators
- Resource-level security for sensitive operations

## Directory Structure

```
Vizion Gateway/
├── Models/           # Data models
├── Services/         # Firebase and API services
├── Views/            # SwiftUI views
│   ├── Admin/        # Admin dashboards
│   ├── Components/   # Reusable components
│   ├── Authentication/ # Login and registration
├── Resources/        # App resources
functions/            # Firebase Functions
```

## Development Workflow

1. Make changes to the iOS app in Xcode
2. Test changes in the Sandbox environment
3. For Firebase Functions changes:
   - Modify code in the `functions` directory
   - Test locally using Firebase Emulator: `firebase emulators:start`
   - Deploy to Firebase: `firebase deploy --only functions`

## License

[Your License Information Here] 