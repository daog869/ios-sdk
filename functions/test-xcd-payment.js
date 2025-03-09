const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, '..', 'vizion-gateway-firebase-adminsdk-fbsvc-cfe0acf447.json');
const test = require('firebase-functions-test')({
  projectId: 'vizion-gateway'
}, serviceAccountPath);

// Initialize Firebase Admin with emulator settings
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8081';
process.env.FIREBASE_FUNCTIONS_EMULATOR_HOST = 'localhost:5002';

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccountPath),
  projectId: 'vizion-gateway'
});

const db = admin.firestore();

async function testXCDPayment() {
  try {
    // First, create test merchant and API key
    const merchantId = 'mer_test12345';
    const apiKey = 'vz_test12345abcdef';

    // Create test merchant
    await db.collection('merchants').doc(merchantId).set({
      merchantId,
      name: 'Test Merchant',
      status: 'active',
      settings: {
        currencies: ['USD', 'XCD'],
        paymentMethods: ['card']
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Create test API key
    await db.collection('apiKeys').add({
      key: apiKey,
      merchantId,
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Test payment data
    const paymentData = {
      amount: 100.00,
      currency: 'XCD',
      merchantId,
      apiKey,
      paymentMethod: {
        type: 'card',
        card: {
          number: '4242424242424242',
          expMonth: 12,
          expYear: 2025,
          cvc: '123'
        }
      },
      description: 'Test XCD Payment',
      metadata: {
        test: true,
        customerName: 'Test Customer'
      }
    };

    // Get the function reference
    const processPayment = test.wrap(require('./index').processPayment);

    // Call the function
    const result = await processPayment(paymentData);
    console.log('Payment Result:', JSON.stringify(result, null, 2));

    // Verify transaction in Firestore
    if (result.transactionId) {
      const txnDoc = await db.collection('transactions').doc(result.transactionId).get();
      if (txnDoc.exists) {
        console.log('Transaction verified in Firestore:', txnDoc.data());
      } else {
        console.error('Transaction not found in Firestore');
      }
    }

  } catch (error) {
    console.error('Test failed:', error);
  } finally {
    // Clean up test data
    try {
      await db.collection('merchants').doc('mer_test12345').delete();
      const apiKeys = await db.collection('apiKeys').where('merchantId', '==', 'mer_test12345').get();
      for (const doc of apiKeys.docs) {
        await doc.ref.delete();
      }
    } catch (cleanupError) {
      console.error('Cleanup failed:', cleanupError);
    }
    // Clean up Firebase test
    test.cleanup();
  }
}

// Run the test
testXCDPayment().then(() => {
  console.log('Test completed');
  process.exit(0);
}).catch(error => {
  console.error('Test failed:', error);
  process.exit(1);
}); 