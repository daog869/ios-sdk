/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");
const cors = require("cors")({ origin: true });
const { HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const path = require("path");
const fs = require("fs");
const crypto = require("crypto");
const os = require("os");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

/**
 * Vizion Gateway - Firebase Cloud Functions
 * Payment processing and merchant management functions
 */

// Initialize Firebase Admin
try {
  // Check if already initialized
  if (admin.apps.length === 0) {
    // Try to load service account from file
    const serviceAccountPath = path.join(__dirname, "..", "vizion-gateway-firebase-adminsdk-fbsvc-cfe0acf447.json");
    if (fs.existsSync(serviceAccountPath)) {
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
      logger.info("Firebase Admin initialized with service account");
    } else {
      // Initialize without service account
      admin.initializeApp();
      logger.warn("Firebase Admin initialized without service account");
    }
  }
} catch (error) {
  logger.error("Failed to initialize Firebase Admin", error);
  // If failed, try one more time with default config
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
}

// Database references
const db = admin.firestore();
let bucket;
try {
  bucket = admin.storage().bucket();
} catch (error) {
  logger.warn("Storage bucket initialization failed, storage features will be disabled", error);
}

// Fee configuration for different currencies
const FEE_CONFIG = {
  USD: {
    percentage: 0.029, // 2.9%
    fixed: 0.30       // $0.30
  },
  XCD: {
    percentage: 0.039, // 3.9%
    fixed: 1.00        // $1.00 XCD
  },
  DEFAULT: {
    percentage: 0.039, // 3.9%
    fixed: 0.40        // $0.40
  }
};

/**
 * Process a payment transaction
 * 
 * This function handles payment processing, including:
 * - Authentication via API key
 * - Transaction record creation
 * - Fee calculation
 * - Webhook notification (if URL provided)
 */
exports.processPayment = functions.https.onCall(async (data, context) => {
  try {
    logger.info("Payment processing request received", { data });

    // Check if data exists
    if (!data) {
      throw new HttpsError("invalid-argument", "No data provided");
    }
    
    // Validate input data
    if (!data.amount || !data.currency || !data.merchantId || !data.apiKey) {
      throw new HttpsError("invalid-argument", "Missing required payment information");
    }

    // Validate API key
    const apiKeyRef = db.collection("apiKeys").where("key", "==", data.apiKey).limit(1);
    const apiKeySnapshot = await apiKeyRef.get();
    
    if (apiKeySnapshot.empty) {
      throw new HttpsError("permission-denied", "Invalid API key");
    }
    
    const apiKeyDoc = apiKeySnapshot.docs[0];
    const apiKeyData = apiKeyDoc.data();
    
    // Verify API key belongs to merchant
    if (apiKeyData.merchantId !== data.merchantId) {
      throw new HttpsError("permission-denied", "API key does not match merchant");
    }
    
    // Check if API key is active
    if (apiKeyData.status !== "active") {
      throw new HttpsError("permission-denied", "API key is not active");
    }

    // Generate transaction ID
    const transactionId = `txn_${crypto.randomBytes(12).toString("hex")}`;
    
    // Get merchant to verify supported currencies
    const merchantDoc = await db.collection("merchants").doc(data.merchantId).get();
    if (!merchantDoc.exists) {
      throw new HttpsError("not-found", "Merchant not found");
    }
    
    const merchantData = merchantDoc.data();
    const supportedCurrencies = merchantData.settings?.currencies || ["USD"];
    
    // Validate currency is supported
    if (!supportedCurrencies.includes(data.currency)) {
      throw new HttpsError("invalid-argument", `Currency ${data.currency} is not supported by this merchant`);
    }
    
    // Calculate fee based on currency
    const feeConfig = FEE_CONFIG[data.currency] || FEE_CONFIG.DEFAULT;
    const feePercentage = feeConfig.percentage;
    const fixedFee = feeConfig.fixed;
    
    const feeAmount = (data.amount * feePercentage) + fixedFee;
    const netAmount = data.amount - feeAmount;
    
    // Create transaction record
    const transactionData = {
      transactionId,
      merchantId: data.merchantId,
      amount: data.amount,
      currency: data.currency,
      feeAmount,
      netAmount,
      status: "completed", // or "pending" based on your flow
      metadata: data.metadata || {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentMethod: data.paymentMethod || "card",
      description: data.description || ""
    };
    
    // Save transaction to Firestore
    await db.collection("transactions").doc(transactionId).set(transactionData);
    
    // If webhook URL is provided, queue a webhook delivery
    if (data.webhookUrl) {
      const webhookId = `whk_${crypto.randomBytes(8).toString("hex")}`;
      
      await db.collection("webhooks").doc(webhookId).set({
        webhookId,
        merchantId: data.merchantId,
        transactionId,
        url: data.webhookUrl,
        event: "payment.completed",
        payload: transactionData,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        attempts: 0,
        maxAttempts: 5
      });
      
      // In a production app, you would trigger a background function or Cloud Task to deliver the webhook
      logger.info("Webhook delivery queued", { webhookId, transactionId });
    }
    
    // Return success response
    return {
      success: true,
      transactionId,
      amount: data.amount,
      currency: data.currency,
      feeAmount,
      netAmount,
      status: "completed",
      createdAt: new Date().toISOString()
    };
  } catch (error) {
    logger.error("Payment processing error", error);
    throw new HttpsError("internal", `Payment processing failed: ${error.message}`);
  }
});

/**
 * Generate a report for merchant transactions
 * 
 * This function creates a CSV report of transactions and returns a download URL
 */
exports.generateReport = functions.https.onCall(async (data, context) => {
  try {
    logger.info("Report generation request received", { data });
    
    // Validate input data
    if (!data.merchantId || !data.apiKey || !data.reportType || !data.startDate || !data.endDate) {
      throw new HttpsError("invalid-argument", "Missing required report parameters");
    }
    
    // Validate API key (same as in processPayment)
    const apiKeyRef = db.collection("apiKeys").where("key", "==", data.apiKey).limit(1);
    const apiKeySnapshot = await apiKeyRef.get();
    
    if (apiKeySnapshot.empty) {
      throw new HttpsError("permission-denied", "Invalid API key");
    }
    
    const apiKeyDoc = apiKeySnapshot.docs[0];
    const apiKeyData = apiKeyDoc.data();
    
    // Verify API key belongs to merchant
    if (apiKeyData.merchantId !== data.merchantId) {
      throw new HttpsError("permission-denied", "API key does not match merchant");
    }
    
    // Parse date strings into Date objects
    const startDate = new Date(data.startDate);
    const endDate = new Date(data.endDate);
    
    // Validate date range
    if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
      throw new HttpsError("invalid-argument", "Invalid date format");
    }
    
    if (endDate < startDate) {
      throw new HttpsError("invalid-argument", "End date must be after start date");
    }
    
    // Fetch transactions for the merchant within the date range
    const transactionsRef = db.collection("transactions")
      .where("merchantId", "==", data.merchantId)
      .where("createdAt", ">=", startDate)
      .where("createdAt", "<=", endDate);
    
    const transactionsSnapshot = await transactionsRef.get();
    
    // Process transactions and create CSV data
    let csvContent = "Transaction ID,Date,Amount,Currency,Fee,Net Amount,Status,Payment Method\n";
    
    transactionsSnapshot.forEach(doc => {
      const txn = doc.data();
      const dateStr = txn.createdAt ? txn.createdAt.toDate().toISOString() : new Date().toISOString();
      
      csvContent += `${txn.transactionId},${dateStr},${txn.amount},${txn.currency},${txn.feeAmount},${txn.netAmount},${txn.status},${txn.paymentMethod}\n`;
    });
    
    // Generate a unique filename for the report
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const reportFilename = `reports/${data.merchantId}/${data.reportType}_${timestamp}.csv`;
    
    // Create a temporary file
    const tempFilePath = path.join(os.tmpdir(), path.basename(reportFilename));
    fs.writeFileSync(tempFilePath, csvContent);
    
    // Upload to Firebase Storage
    await bucket.upload(tempFilePath, {
      destination: reportFilename,
      metadata: {
        contentType: "text/csv",
        metadata: {
          reportType: data.reportType,
          merchantId: data.merchantId,
          startDate: startDate.toISOString(),
          endDate: endDate.toISOString(),
          generatedAt: new Date().toISOString()
        }
      }
    });
    
    // Delete the temporary file
    fs.unlinkSync(tempFilePath);
    
    // Generate a signed URL for the file (expires in 1 hour)
    const [signedUrl] = await bucket.file(reportFilename).getSignedUrl({
      action: "read",
      expires: Date.now() + 3600000 // 1 hour
    });
    
    return {
      success: true,
      reportType: data.reportType,
      startDate: startDate.toISOString(),
      endDate: endDate.toISOString(),
      transactionCount: transactionsSnapshot.size,
      downloadUrl: signedUrl,
      expiresAt: new Date(Date.now() + 3600000).toISOString()
    };
  } catch (error) {
    logger.error("Report generation error", error);
    throw new HttpsError("internal", `Report generation failed: ${error.message}`);
  }
});

/**
 * Get transaction statistics for a merchant
 * 
 * This function calculates statistics like total volume, average transaction size,
 * and count by payment method for a specified time period
 */
exports.getTransactionStatistics = functions.https.onCall(async (data, context) => {
  try {
    logger.info("Transaction statistics request received", { data });
    
    // Validate input data
    if (!data.merchantId || !data.apiKey || !data.timeframe) {
      throw new HttpsError("invalid-argument", "Missing required parameters");
    }
    
    // Validate API key (same as in processPayment)
    const apiKeyRef = db.collection("apiKeys").where("key", "==", data.apiKey).limit(1);
    const apiKeySnapshot = await apiKeyRef.get();
    
    if (apiKeySnapshot.empty) {
      throw new HttpsError("permission-denied", "Invalid API key");
    }
    
    const apiKeyDoc = apiKeySnapshot.docs[0];
    const apiKeyData = apiKeyDoc.data();
    
    // Verify API key belongs to merchant
    if (apiKeyData.merchantId !== data.merchantId) {
      throw new HttpsError("permission-denied", "API key does not match merchant");
    }
    
    // Calculate start date based on timeframe
    const now = new Date();
    let startDate;
    
    switch (data.timeframe) {
      case "today":
        startDate = new Date(now.setHours(0, 0, 0, 0));
        break;
      case "yesterday":
        startDate = new Date(now.setDate(now.getDate() - 1));
        startDate.setHours(0, 0, 0, 0);
        break;
      case "last7days":
        startDate = new Date(now.setDate(now.getDate() - 7));
        break;
      case "last30days":
        startDate = new Date(now.setDate(now.getDate() - 30));
        break;
      case "thisMonth":
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        break;
      case "lastMonth":
        startDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        break;
      default:
        throw new HttpsError("invalid-argument", "Invalid timeframe specified");
    }
    
    // Fetch transactions for the merchant within the timeframe
    const transactionsRef = db.collection("transactions")
      .where("merchantId", "==", data.merchantId)
      .where("createdAt", ">=", startDate);
    
    const transactionsSnapshot = await transactionsRef.get();
    
    // Calculate statistics
    let totalVolume = 0;
    let totalFees = 0;
    let totalNet = 0;
    let transactionCount = 0;
    const paymentMethodCounts = {};
    const currencyCounts = {};
    
    transactionsSnapshot.forEach(doc => {
      const txn = doc.data();
      totalVolume += txn.amount;
      totalFees += txn.feeAmount;
      totalNet += txn.netAmount;
      transactionCount++;
      
      // Count by payment method
      paymentMethodCounts[txn.paymentMethod] = (paymentMethodCounts[txn.paymentMethod] || 0) + 1;
      
      // Count by currency
      currencyCounts[txn.currency] = (currencyCounts[txn.currency] || 0) + 1;
    });
    
    // Return statistics
    return {
      success: true,
      timeframe: data.timeframe,
      startDate: startDate.toISOString(),
      endDate: new Date().toISOString(),
      totalVolume,
      totalFees,
      totalNet,
      transactionCount,
      averageTransactionSize: transactionCount > 0 ? totalVolume / transactionCount : 0,
      paymentMethodBreakdown: paymentMethodCounts,
      currencyBreakdown: currencyCounts
    };
  } catch (error) {
    logger.error("Transaction statistics error", error);
    throw new HttpsError("internal", `Transaction statistics failed: ${error.message}`);
  }
});
