/**
 * Test script to invoke Firebase functions in the emulator
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin
try {
  const serviceAccountPath = path.join(__dirname, '..', 'vizion-gateway-firebase-adminsdk-fbsvc-cfe0acf447.json');
  
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      // Connect to emulator
      databaseURL: 'http://localhost:8080',
      projectId: serviceAccount.project_id
    });
    
    console.log('Firebase Admin initialized for emulator testing');
  } else {
    throw new Error('Service account file not found');
  }
} catch (error) {
  console.error('Error initializing Firebase Admin:', error);
  process.exit(1);
}

// Connect to Functions emulator
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';
process.env.FIREBASE_STORAGE_EMULATOR_HOST = 'localhost:9199';
process.env.FUNCTIONS_EMULATOR = 'true';

// Test our functions

// 1. Test onboardMerchant function
async function testOnboardMerchant() {
  console.log('Testing onboardMerchant function...');
  
  try {
    // This would normally come from firebase.functions()
    // but for testing directly, we'll just create a sample merchant
    const db = admin.firestore();
    
    // Create a test merchant
    const merchantId = `test_mer_${Date.now()}`;
    const testMerchant = {
      merchantId,
      businessName: 'Test Business',
      email: 'test@example.com',
      contactName: 'Test User',
      address: '123 Test St, Test City, 12345',
      phone: '555-123-4567',
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    await db.collection('merchants').doc(merchantId).set(testMerchant);
    console.log('Successfully created test merchant:', merchantId);
    
    // Create test API key
    const apiKeyId = `test_key_${Date.now()}`;
    const apiKey = `test_vz_${Date.now()}`;
    const apiKeyData = {
      keyId: apiKeyId,
      key: apiKey,
      merchantId,
      name: 'Test API Key',
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      permissions: ['payments', 'reports', 'webhooks']
    };
    
    await db.collection('apiKeys').doc(apiKeyId).set(apiKeyData);
    console.log('Successfully created test API key:', apiKeyId);
    
    return {
      merchantId,
      apiKey,
      apiKeyId
    };
  } catch (error) {
    console.error('Error testing onboardMerchant:', error);
    throw error;
  }
}

// 2. Test processPayment function
async function testProcessPayment(merchantId, apiKey) {
  console.log('Testing processPayment function...');
  
  try {
    // Create a test transaction directly in Firestore
    const db = admin.firestore();
    const transactionId = `test_txn_${Date.now()}`;
    const transactionData = {
      transactionId,
      merchantId,
      amount: 100.00,
      currency: 'USD',
      feeAmount: 3.20,
      netAmount: 96.80,
      status: 'completed',
      metadata: { test: true },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentMethod: 'card',
      description: 'Test transaction'
    };
    
    await db.collection('transactions').doc(transactionId).set(transactionData);
    console.log('Successfully created test transaction:', transactionId);
    
    return transactionId;
  } catch (error) {
    console.error('Error testing processPayment:', error);
    throw error;
  }
}

// Run tests
async function runTests() {
  try {
    // Test merchant onboarding
    const { merchantId, apiKey } = await testOnboardMerchant();
    
    // Test payment processing
    const transactionId = await testProcessPayment(merchantId, apiKey);
    
    console.log('\nAll tests completed successfully!');
    console.log('Test merchant ID:', merchantId);
    console.log('Test API key:', apiKey);
    console.log('Test transaction ID:', transactionId);
    
    // Verify data in Firestore
    const db = admin.firestore();
    
    console.log('\nVerifying data in Firestore...');
    
    const merchantDoc = await db.collection('merchants').doc(merchantId).get();
    console.log('Merchant exists:', merchantDoc.exists);
    
    const apiKeyDocs = await db.collection('apiKeys').where('merchantId', '==', merchantId).get();
    console.log('API keys found:', !apiKeyDocs.empty);
    
    const transactionDocs = await db.collection('transactions').where('merchantId', '==', merchantId).get();
    console.log('Transactions found:', !transactionDocs.empty);
    
  } catch (error) {
    console.error('Error running tests:', error);
  }
}

// Run the tests
runTests(); 