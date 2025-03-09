# Firebase Setup for Vizion Gateway

## 1. Add Firebase SDK via Swift Package Manager (SPM)

1. In Xcode, select **File > Add Packages...**
2. Paste the Firebase iOS SDK GitHub URL: `https://github.com/firebase/firebase-ios-sdk.git`
3. Click **Add Package**
4. Select the following packages:
   - FirebaseCore
   - FirebaseAuth
   - FirebaseFirestore 
   - FirebaseStorage
   - FirebaseFunctions
   - DO NOT select FirebaseFirestoreSwift (as requested)
5. Click **Add Package**

## 2. Configure Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Create a new project (or use an existing one)
3. Add an iOS app to your Firebase project:
   - Register app with your bundle identifier (e.g., com.viziongateway.app)
   - Download the GoogleService-Info.plist file
   - Replace the placeholder GoogleService-Info.plist in your project with the downloaded file

## 3. Enable Firebase Services

### Authentication
1. In Firebase Console, go to **Authentication**
2. Enable **Email/Password** authentication
3. Optionally, add test users in the "Users" tab for development

### Firestore Database
1. In Firebase Console, go to **Firestore Database**
2. Click **Create Database**
3. Choose a starting mode (Test mode for development is fine)
4. Choose a location
5. Set up the following collections:
   - users
   - transactions
   - apiKeys
   - webhooks

### Storage
1. In Firebase Console, go to **Storage**
2. Click **Get Started**
3. Choose a starting mode (Test mode for development is fine)
4. Select a location (same as your Firestore database)

### Functions (Optional)
1. In Firebase Console, go to **Functions**
2. Click **Get Started**
3. Follow the prompts to set up Firebase Functions
4. This requires Node.js and Firebase CLI for local development

## 4. Configure Security Rules

### Firestore Rules
In Firestore Database, go to the "Rules" tab and set up basic rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Storage Rules
In Storage, go to the "Rules" tab and set up basic rules:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**Note:** These are basic development rules. For production, you'll want more restrictive rules.

## 5. Test Your Integration

1. Run the app and check the console for Firebase initialization success
2. Try creating a test user through the app's registration flow
3. Verify the user appears in Firebase Authentication console
4. Test file uploads to Firebase Storage
5. Test cloud functions if you've set them up

## 6. Next Steps

- Implement proper error handling for Firebase operations
- Add additional Firebase services as needed:
  - Analytics
  - Crashlytics
  - Performance Monitoring
  - Remote Config
- Set up Cloud Functions for backend processing
- Configure proper security rules for production
- Implement offline capabilities with Firestore caching 