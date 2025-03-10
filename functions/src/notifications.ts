import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

// Initialize admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

interface NotificationPayload {
    title: string;
    body: string;
    category: string;
    transactionId?: string;
    metadata?: Record<string, string | number | boolean | object>;
}

// Send notification to specific user
export const sendNotificationToUser = async (
  userId: string,
  payload: NotificationPayload
): Promise<void> => {
  try {
    // Get user's FCM tokens
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();

    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) {
      console.log(`No FCM token found for user ${userId}`);
      return;
    }

    // Create message
    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: {
        category: payload.category,
        ...(payload.transactionId && { transactionId: payload.transactionId }),
        ...(payload.metadata && { metadata: JSON.stringify(payload.metadata) }),
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    // Send message
    const response = await admin.messaging().send(message);
    console.log("Successfully sent notification:", response);
  } catch (error) {
    console.error("Error sending notification:", error);
    throw error;
  }
};

// Send notification to topic subscribers
export const sendNotificationToTopic = async (
  topic: string,
  payload: NotificationPayload
): Promise<void> => {
  try {
    const message: admin.messaging.Message = {
      topic,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: {
        category: payload.category,
        ...(payload.transactionId && { transactionId: payload.transactionId }),
        ...(payload.metadata && { metadata: JSON.stringify(payload.metadata) }),
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log(`Successfully sent notification to topic ${topic}:`, response);
  } catch (error) {
    console.error("Error sending notification to topic:", error);
    throw error;
  }
};

// Transaction notification triggers
export const onTransactionCreated = functions.firestore.onDocumentCreated(
  "transactions/{transactionId}",
  async (event) => {
    const transaction = event.data?.data();
    if (!transaction) return;

    const { customerId, merchantId, amount, currency, status } = transaction;

    // Notify customer of payment sent
    if (customerId) {
      await sendNotificationToUser(customerId, {
        title: "Payment Sent",
        body: `Your payment of ${amount} ${currency} has been processed`,
        category: "TRANSACTION",
        transactionId: event.params.transactionId,
        metadata: {
          status,
          amount,
          currency,
        },
      });
    }

    // Notify merchant of payment received
    if (merchantId) {
      await sendNotificationToUser(merchantId, {
        title: "Payment Received",
        body: `You received a payment of ${amount} ${currency}`,
        category: "TRANSACTION",
        transactionId: event.params.transactionId,
        metadata: {
          status,
          amount,
          currency,
        },
      });
    }

    // Send high-value transaction notifications
    const threshold = 500; // Configure threshold as needed
    if (amount > threshold) {
      await sendNotificationToTopic("security", {
        title: "High-Value Transaction",
        body: `Transaction of ${amount} ${currency} requires review`,
        category: "SECURITY",
        transactionId: event.params.transactionId,
        metadata: {
          requiresAction: true,
          amount,
          currency,
        },
      });
    }
  }
);

// Dispute notification trigger
export const onDisputeCreated = functions.firestore.onDocumentCreated(
  "disputes/{disputeId}",
  async (event) => {
    const dispute = event.data?.data();
    if (!dispute) return;

    const { merchantId, transactionId, amount, currency } = dispute;

    if (merchantId) {
      await sendNotificationToUser(merchantId, {
        title: "New Dispute",
        body: `A dispute for ${amount} ${currency} has been filed`,
        category: "TRANSACTION",
        transactionId,
        metadata: {
          disputeId: event.params.disputeId,
          amount,
          currency,
        },
      });
    }

    // Notify dispute team
    await sendNotificationToTopic("disputes", {
      title: "New Dispute Filed",
      body: `Dispute for transaction ${transactionId} requires review`,
      category: "TRANSACTION",
      transactionId,
      metadata: {
        disputeId: event.params.disputeId,
        amount,
        currency,
      },
    });
  }
);

// Refund notification trigger
export const onRefundCreated = functions.firestore.onDocumentCreated(
  "refunds/{refundId}",
  async (event) => {
    const refund = event.data?.data();
    if (!refund) return;

    const { customerId, merchantId, amount, currency, transactionId } = refund;

    // Notify customer
    if (customerId) {
      await sendNotificationToUser(customerId, {
        title: "Refund Processed",
        body: `A refund of ${amount} ${currency} has been processed`,
        category: "TRANSACTION",
        transactionId,
        metadata: {
          refundId: event.params.refundId,
          amount,
          currency,
        },
      });
    }

    // Notify merchant
    if (merchantId) {
      await sendNotificationToUser(merchantId, {
        title: "Refund Issued",
        body: `You issued a refund of ${amount} ${currency}`,
        category: "TRANSACTION",
        transactionId,
        metadata: {
          refundId: event.params.refundId,
          amount,
          currency,
        },
      });
    }
  }
);

// Security alert notification
export const onSecurityAlert = functions.firestore.onDocumentCreated(
  "securityAlerts/{alertId}",
  async (event) => {
    const alert = event.data?.data();
    if (!alert) return;

    const { userId, type, severity, details } = alert;

    // Notify affected user
    if (userId) {
      await sendNotificationToUser(userId, {
        title: "Security Alert",
        body: `${type}: ${details}`,
        category: "SECURITY",
        metadata: {
          alertId: event.params.alertId,
          type,
          severity,
        },
      });
    }

    // Notify security team for high-severity alerts
    if (severity === "high") {
      await sendNotificationToTopic("security", {
        title: "High-Severity Security Alert",
        body: `${type}: ${details}`,
        category: "SECURITY",
        metadata: {
          alertId: event.params.alertId,
          type,
          severity,
          userId,
        },
      });
    }
  }
);

// Account update notification
export const onAccountUpdate = functions.firestore.onDocumentUpdated(
  "users/{userId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const userId = event.params.userId;

    // Check for significant changes
    if (
      before.email !== after.email ||
            before.phone !== after.phone ||
            before.status !== after.status
    ) {
      await sendNotificationToUser(userId, {
        title: "Account Updated",
        body: "Your account information has been updated",
        category: "ACCOUNT",
        metadata: {
          updateType: "profile",
          changes: {
            email: before.email !== after.email,
            phone: before.phone !== after.phone,
            status: before.status !== after.status,
          },
        },
      });
    }
  }
);

// API key notification
export const onAPIKeyCreated = functions.firestore.onDocumentCreated(
  "apiKeys/{keyId}",
  async (event) => {
    const apiKey = event.data?.data();
    if (!apiKey) return;

    const { merchantId, name } = apiKey;

    if (merchantId) {
      await sendNotificationToUser(merchantId, {
        title: "New API Key Created",
        body: `A new API key '${name}' has been created`,
        category: "SECURITY",
        metadata: {
          keyId: event.params.keyId,
          name,
        },
      });

      // Notify security team
      await sendNotificationToTopic("security", {
        title: "API Key Created",
        body: `New API key created for merchant ${merchantId}`,
        category: "SECURITY",
        metadata: {
          keyId: event.params.keyId,
          merchantId,
          name,
        },
      });
    }
  }
);
