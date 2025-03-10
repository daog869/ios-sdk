# Vizion Gateway Functions

This directory contains Firebase Cloud Functions for the Vizion Gateway payment processing platform.

## Setup Instructions

1. Install dependencies:
   ```bash
   npm install
   ```

2. Setup Firebase credential file:
   - Download your Firebase service account key from Firebase Console > Project Settings > Service Accounts
   - Save it as `service-account-key.json` in this directory

## Data Seeding for Testing

To populate your Firebase database with test data for UI development:

1. Make sure you have the `service-account-key.json` file in this directory
2. Run the seeding script:
   ```bash
   npm run seed
   ```

This will create:
- 3 test merchants
- 5 test users (admin, merchants, customers)
- 50 sample transactions
- API keys and webhooks

### Test Accounts

After running the seed script, you can log in with these credentials:

| Role      | Email                     | Password     |
|-----------|---------------------------|--------------|
| Admin     | admin@viziongateway.com   | Password123! |
| Merchant  | merchant1@coffeeshop.com  | Password123! |
| Customer  | jane.smith@example.com    | Password123! |

## Firebase Emulators

To run Firebase emulators locally:

1. Start the emulators:
   ```bash
   firebase emulators:start
   ```

2. Access the emulator UI at:
   - Emulator Hub: http://localhost:4000
   - Functions: http://localhost:5001
   - Firestore: http://localhost:8080
   - Auth: http://localhost:9099

## Development Workflow

1. Start the emulators with:
   ```bash
   npm run serve
   ```

2. Run the seed script to populate test data:
   ```bash
   npm run seed
   ```

3. Launch the Vizion Gateway app pointing to the local emulators

## Troubleshooting

- If you encounter auth issues, make sure the user accounts exist in Firebase Auth
- If you're using the emulators, ensure your app is configured to use them
- Check Firebase logs with `npm run logs` if functions aren't working as expected 