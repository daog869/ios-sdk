/**
 * Seed Data Script for Vizion Gateway
 * 
 * This script populates the Firebase database with test data for development.
 * It creates merchants, transactions, users, and API keys for testing the UI.
 */

const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.join(__dirname, '../vizion-gateway-firebase-adminsdk-fbsvc-cfe0acf447.json'));

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();
const auth = admin.auth();

// Clear collections first
async function clearCollections() {
  console.log('Clearing existing data...');
  
  const collections = ['merchants', 'transactions', 'users', 'apiKeys', 'webhooks'];
  
  for (const collection of collections) {
    const snapshot = await db.collection(collection).get();
    const batchSize = snapshot.size;
    
    if (batchSize === 0) {
      console.log(`No documents to delete in ${collection}`);
      continue;
    }
    
    // Delete documents in batches
    const batches = [];
    let batch = db.batch();
    let count = 0;
    
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
      count++;
      
      if (count >= 500) {  // Firestore batch limit
        batches.push(batch.commit());
        batch = db.batch();
        count = 0;
      }
    });
    
    if (count > 0) {
      batches.push(batch.commit());
    }
    
    await Promise.all(batches);
    console.log(`Deleted ${batchSize} documents from ${collection}`);
  }
}

// Create test merchants
async function createMerchants() {
  console.log('Creating test merchants...');
  
  const merchants = [
    {
      id: 'MERCH001',
      name: 'Coffee Shop',
      email: 'contact@coffeeshop.com',
      phone: '+1-869-555-0101',
      address: '123 Main St, Basseterre',
      status: 'active',
      businessType: 'retail',
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      environment: 'sandbox'
    },
    {
      id: 'MERCH002',
      name: 'Electronics Store',
      email: 'sales@electronics.com',
      phone: '+1-869-555-0202',
      address: '456 Market Ave, Charlestown',
      status: 'active',
      businessType: 'retail',
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      environment: 'sandbox'
    },
    {
      id: 'MERCH003',
      name: 'Grocery Market',
      email: 'orders@grocerymarket.com',
      phone: '+1-869-555-0303',
      address: '789 Beach Rd, Basseterre',
      status: 'active',
      businessType: 'retail',
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      environment: 'sandbox'
    }
  ];
  
  for (const merchant of merchants) {
    await db.collection('merchants').doc(merchant.id).set(merchant);
  }
  
  console.log(`Created ${merchants.length} merchants`);
  return merchants;
}

// Create test users (admin, merchant users, customers)
async function createUsers() {
  console.log('Creating test users...');
  
  // Create admin user
  const adminUser = {
    id: 'admin123',
    firstName: 'Admin',
    lastName: 'User',
    email: 'admin@viziongateway.com',
    role: 'admin',
    isActive: true,
    createdAt: admin.firestore.Timestamp.now(),
    lastLogin: admin.firestore.Timestamp.now(),
    environment: 'sandbox'
  };
  
  // Create merchant users
  const merchantUsers = [
    {
      id: 'merchant001',
      firstName: 'Merchant',
      lastName: 'One',
      email: 'merchant1@coffeeshop.com',
      role: 'merchant',
      merchantId: 'MERCH001',
      isActive: true,
      createdAt: admin.firestore.Timestamp.now(),
      lastLogin: admin.firestore.Timestamp.now(),
      environment: 'sandbox'
    },
    {
      id: 'merchant002',
      firstName: 'Merchant',
      lastName: 'Two',
      email: 'merchant2@electronics.com',
      role: 'merchant',
      merchantId: 'MERCH002',
      isActive: true,
      createdAt: admin.firestore.Timestamp.now(),
      lastLogin: admin.firestore.Timestamp.now(),
      environment: 'sandbox'
    }
  ];
  
  // Create customer users
  const customerUsers = [
    {
      id: 'cust001',
      firstName: 'Jane',
      lastName: 'Smith',
      email: 'jane.smith@example.com',
      role: 'customer',
      isActive: true,
      createdAt: admin.firestore.Timestamp.now(),
      lastLogin: admin.firestore.Timestamp.now(),
      environment: 'sandbox'
    },
    {
      id: 'cust002',
      firstName: 'John',
      lastName: 'Doe',
      email: 'john.doe@example.com',
      role: 'customer',
      isActive: true,
      createdAt: admin.firestore.Timestamp.now(),
      lastLogin: admin.firestore.Timestamp.now(),
      environment: 'sandbox'
    }
  ];
  
  // Save users to Firestore
  const allUsers = [adminUser, ...merchantUsers, ...customerUsers];
  for (const user of allUsers) {
    await db.collection('users').doc(user.id).set(user);
    
    // Create auth user if needed
    try {
      await auth.createUser({
        uid: user.id,
        email: user.email,
        password: 'Password123!',
        displayName: `${user.firstName} ${user.lastName}`
      });
    } catch (error) {
      if (error.code === 'auth/uid-already-exists' || error.code === 'auth/email-already-exists') {
        console.log(`User auth already exists for ${user.email}`);
      } else {
        console.error(`Error creating auth user for ${user.email}:`, error);
      }
    }
  }
  
  console.log(`Created ${allUsers.length} users`);
  return allUsers;
}

// Create test API keys
async function createAPIKeys() {
  console.log('Creating test API keys...');
  
  const apiKeys = [
    {
      key: 'vz_sk_sandbox_1234567890abcdef',
      merchantId: 'MERCH001',
      name: 'Coffee Shop API Key',
      active: true,
      createdAt: admin.firestore.Timestamp.now(),
      environment: 'sandbox',
      scopes: ['read:transactions', 'write:transactions']
    },
    {
      key: 'vz_sk_sandbox_0987654321fedcba',
      merchantId: 'MERCH002',
      name: 'Electronics Store API Key',
      active: true,
      createdAt: admin.firestore.Timestamp.now(),
      environment: 'sandbox',
      scopes: ['read:transactions', 'write:transactions']
    }
  ];
  
  for (const apiKey of apiKeys) {
    await db.collection('apiKeys').add(apiKey);
  }
  
  console.log(`Created ${apiKeys.length} API keys`);
}

// Create test transactions
async function createTransactions() {
  console.log('Creating test transactions...');
  
  const transactionTypes = ['payment', 'refund', 'payout'];
  const statuses = ['pending', 'processing', 'completed', 'failed', 'refunded', 'disputed', 'cancelled'];
  const paymentMethods = ['debitCard', 'creditCard', 'bankTransfer', 'mobileMoney', 'qrCode', 'wallet'];
  
  const transactions = [];
  const now = new Date();
  
  // Generate 50 random transactions
  for (let i = 1; i <= 50; i++) {
    const txType = transactionTypes[Math.floor(Math.random() * transactionTypes.length)];
    const status = statuses[Math.floor(Math.random() * statuses.length)];
    const method = paymentMethods[Math.floor(Math.random() * paymentMethods.length)];
    const merchantId = `MERCH00${Math.floor(Math.random() * 3) + 1}`;
    const merchantName = merchantId === 'MERCH001' ? 'Coffee Shop' : 
                        merchantId === 'MERCH002' ? 'Electronics Store' : 'Grocery Market';
    
    // Create random date within the last 30 days
    const date = new Date(now);
    date.setDate(date.getDate() - Math.floor(Math.random() * 30));
    
    // Create random amount between $5 and $1000
    const amount = (Math.random() * 995 + 5).toFixed(2);
    const fee = (amount * 0.025).toFixed(2); // 2.5% fee
    const netAmount = (parseFloat(amount) - parseFloat(fee)).toFixed(2);
    
    const transaction = {
      id: `TX${String(i).padStart(6, '0')}`,
      amount: parseFloat(amount),
      currency: 'XCD',
      status: status,
      type: txType,
      paymentMethod: method,
      timestamp: admin.firestore.Timestamp.fromDate(date),
      transactionDescription: `${merchantName} Transaction`,
      merchantId: merchantId,
      merchantName: merchantName,
      customerId: Math.random() > 0.5 ? 'cust001' : 'cust002',
      customerName: Math.random() > 0.5 ? 'Jane Smith' : 'John Doe',
      reference: `REF-${Math.random().toString(36).substring(2, 10).toUpperCase()}`,
      fee: parseFloat(fee),
      netAmount: parseFloat(netAmount),
      environment: 'sandbox'
    };
    
    transactions.push(transaction);
  }
  
  // Add transactions to Firestore
  for (const transaction of transactions) {
    await db.collection('transactions').doc(transaction.id).set(transaction);
  }
  
  console.log(`Created ${transactions.length} transactions`);
}

// Create test webhooks
async function createWebhooks() {
  console.log('Creating test webhooks...');
  
  const webhooks = [
    {
      id: 'whk_12345',
      url: 'https://webhook.site/123456-test-endpoint',
      events: ['transaction.created', 'transaction.updated'],
      merchantId: 'MERCH001',
      createdAt: admin.firestore.Timestamp.now(),
      environment: 'sandbox',
      active: true
    },
    {
      id: 'whk_67890',
      url: 'https://example.com/webhook/callback',
      events: ['transaction.created', 'refund.created'],
      merchantId: 'MERCH002',
      createdAt: admin.firestore.Timestamp.now(),
      environment: 'sandbox',
      active: true
    }
  ];
  
  for (const webhook of webhooks) {
    await db.collection('webhooks').doc(webhook.id).set(webhook);
  }
  
  console.log(`Created ${webhooks.length} webhooks`);
}

// Main function
async function seedDatabase() {
  try {
    console.log('Starting database seeding...');
    
    // Clear existing data
    await clearCollections();
    
    // Create test data
    await createMerchants();
    await createUsers();
    await createAPIKeys();
    await createTransactions();
    await createWebhooks();
    
    console.log('Database seeding completed successfully!');
    console.log('\nTest Accounts:');
    console.log('Admin: admin@viziongateway.com / Password123!');
    console.log('Merchant: merchant1@coffeeshop.com / Password123!');
    console.log('Customer: jane.smith@example.com / Password123!');
    
  } catch (error) {
    console.error('Error seeding database:', error);
  }
}

// Run the seed function
seedDatabase(); 