/**
 * Setup Test Data - Vizion Gateway
 * 
 * This script creates test data in Firebase Firestore for local development and testing.
 */

const admin = require('firebase-admin');
const path = require('path');
const crypto = require('crypto');
const fs = require('fs');

console.log('Setting up test data for Vizion Gateway...');

// Initialize Firebase Admin
let serviceAccount;
try {
  const serviceAccountPath = path.join(__dirname, '..', 'vizion-gateway-firebase-adminsdk-fbsvc-cfe0acf447.json');
  
  if (fs.existsSync(serviceAccountPath)) {
    serviceAccount = require(serviceAccountPath);
    
    // Connect to local emulator
    process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8081';
    process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';
    process.env.FIREBASE_STORAGE_EMULATOR_HOST = 'localhost:9199';
    
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id
    });
    
    console.log('Firebase Admin initialized for emulator testing');
  } else {
    throw new Error('Service account file not found at: ' + serviceAccountPath);
  }
} catch (error) {
  console.error('Error initializing Firebase Admin:', error);
  process.exit(1);
}

// Firestore reference
const db = admin.firestore();

// Generate consistent test IDs
const TEST_MERCHANT_ID = 'mer_test12345';
const TEST_API_KEY_ID = 'key_test12345';
const TEST_API_KEY = 'vz_test12345abcdef';

// Create test data in Firestore
async function setupTestData() {
  try {
    // 1. Create test merchant
    const merchantData = {
      merchantId: TEST_MERCHANT_ID,
      businessName: 'Test Business',
      email: 'test@example.com',
      contactName: 'Test User',
      address: '123 Test St, Test City, 12345',
      phone: '555-123-4567',
      website: 'https://example.com',
      taxId: 'TAX-12345',
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: 'system',
      settings: {
        webhookUrl: 'https://example.com/webhook',
        paymentMethods: ['card', 'ach'],
        currencies: ['XCD', 'USD', 'EUR']
      }
    };
    
    await db.collection('merchants').doc(TEST_MERCHANT_ID).set(merchantData);
    console.log('Created test merchant:', TEST_MERCHANT_ID);
    
    // 2. Create test API key
    const apiKeyData = {
      keyId: TEST_API_KEY_ID,
      key: TEST_API_KEY,
      merchantId: TEST_MERCHANT_ID,
      name: 'Test API Key',
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: 'system',
      permissions: ['payments', 'reports', 'webhooks']
    };
    
    await db.collection('apiKeys').doc(TEST_API_KEY_ID).set(apiKeyData);
    console.log('Created test API key:', TEST_API_KEY_ID);
    
    // 3. Create test transactions
    const transactionTypes = ['completed', 'failed', 'pending'];
    const paymentMethods = ['card', 'ach', 'wallet'];
    const currencies = ['XCD', 'USD', 'EUR', 'GBP'];
    
    for (let i = 0; i < 10; i++) {
      const amount = (Math.random() * 1000).toFixed(2);
      const currency = currencies[Math.floor(Math.random() * currencies.length)];
      const status = transactionTypes[Math.floor(Math.random() * transactionTypes.length)];
      const paymentMethod = paymentMethods[Math.floor(Math.random() * paymentMethods.length)];
      
      // Calculate fees
      const feePercentage = currency === 'USD' ? 0.029 : 0.039;
      const fixedFee = currency === 'USD' ? 0.30 : 0.40;
      const feeAmount = (amount * feePercentage) + fixedFee;
      const netAmount = amount - feeAmount;
      
      const transactionId = `txn_test${i}${crypto.randomBytes(4).toString('hex')}`;
      const timestamp = new Date();
      timestamp.setDate(timestamp.getDate() - Math.floor(Math.random() * 30)); // Random date in last 30 days
      
      const transactionData = {
        transactionId,
        merchantId: TEST_MERCHANT_ID,
        amount: parseFloat(amount),
        currency,
        feeAmount,
        netAmount,
        status,
        metadata: { test: true, index: i },
        createdAt: timestamp,
        updatedAt: timestamp,
        paymentMethod,
        description: `Test transaction ${i}`
      };
      
      await db.collection('transactions').doc(transactionId).set(transactionData);
    }
    console.log('Created 10 test transactions');
    
    // 4. Create specific XCD transaction
    const xcdTransactionId = `txn_xcd_${crypto.randomBytes(8).toString('hex')}`;
    const xcdAmount = 250.00;
    const feePercentage = 0.039; // 3.9% for XCD
    const fixedFee = 0.40;
    const feeAmount = (xcdAmount * feePercentage) + fixedFee;
    const netAmount = xcdAmount - feeAmount;
    
    const xcdTransactionData = {
      transactionId: xcdTransactionId,
      merchantId: TEST_MERCHANT_ID,
      amount: xcdAmount,
      currency: 'XCD',
      feeAmount,
      netAmount,
      status: 'completed',
      metadata: { test: true, isXCD: true },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentMethod: 'card',
      description: 'EC Dollar Test Transaction'
    };
    
    await db.collection('transactions').doc(xcdTransactionId).set(xcdTransactionData);
    console.log('Created specific XCD transaction:', xcdTransactionId);
    
    // 5. Create test webhooks
    const webhookId = `whk_test${crypto.randomBytes(8).toString('hex')}`;
    const webhookData = {
      webhookId,
      merchantId: TEST_MERCHANT_ID,
      url: 'https://example.com/webhook',
      event: 'payment.completed',
      status: 'delivered',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      attempts: 1,
      maxAttempts: 5,
      isTest: true,
      lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
      statusCode: 200,
      responseBody: 'OK'
    };
    
    await db.collection('webhooks').doc(webhookId).set(webhookData);
    console.log('Created test webhook:', webhookId);
    
    console.log('\nTest data setup complete!');
    console.log('\nTest credentials:');
    console.log('  Merchant ID:', TEST_MERCHANT_ID);
    console.log('  API Key:', TEST_API_KEY);
    console.log('\nYou can now use these credentials to test the Firebase functions.');
    console.log('\nTo test with XCD currency, use:');
    console.log('  curl -s "http://localhost:5002/vizion-gateway/us-central1/processPayment" \\');
    console.log('    -H "Content-Type: application/json" \\');
    console.log('    -d \'{"data":{"amount":100,"currency":"XCD","merchantId":"mer_test12345","apiKey":"vz_test12345abcdef"}}\'');
    
    return true;
  } catch (error) {
    console.error('Error setting up test data:', error);
    return false;
  }
}

// Run setup
setupTestData()
  .then(() => {
    console.log('Setup completed successfully!');
    process.exit(0);
  })
  .catch(error => {
    console.error('Setup failed:', error);
    process.exit(1);
  }); 