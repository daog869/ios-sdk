/**
 * Test script to verify service account loading
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

console.log('Testing service account loading...');

// Try to load service account file
try {
  const serviceAccountPath = path.join(__dirname, '..', 'vizion-gateway-firebase-adminsdk-fbsvc-cfe0acf447.json');
  console.log(`Looking for service account at: ${serviceAccountPath}`);
  
  if (fs.existsSync(serviceAccountPath)) {
    console.log('Service account file exists! Loading content...');
    const serviceAccount = require(serviceAccountPath);
    console.log('Service account loaded successfully. Project ID:', serviceAccount.project_id);
    
    // Initialize Firebase Admin
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    
    console.log('Firebase Admin initialized successfully with service account!');
  } else {
    console.error('Service account file not found at path:', serviceAccountPath);
  }
} catch (error) {
  console.error('Error loading service account:', error);
} 