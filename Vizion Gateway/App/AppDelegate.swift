import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    let gcmMessageIDKey = "gcm.message_id"
    
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Set messaging delegate
        Messaging.messaging().delegate = self
        
        // Register for remote notifications
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = NotificationService.shared
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { _, _ in }
            )
        } else {
            let settings: UIUserNotificationSettings =
            UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        
        application.registerForRemoteNotifications()
        
        return true
    }
    
    // Handle notification registration
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // Handle notification reception
    func application(_ application: UIApplication,
                    didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async
    -> UIBackgroundFetchResult {
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Handle the notification data
        handleNotification(userInfo)
        
        return UIBackgroundFetchResult.newData
    }
    
    private func handleNotification(_ userInfo: [AnyHashable: Any]) {
        // Extract notification data
        guard let category = userInfo["category"] as? String,
              let title = userInfo["title"] as? String,
              let body = userInfo["body"] as? String else {
            return
        }
        
        // Create notification category
        guard let notificationCategory = NotificationCategory(rawValue: category) else {
            return
        }
        
        // Extract additional data
        let transactionId = userInfo["transactionId"] as? String
        let metadata = userInfo["metadata"] as? [String: Any] ?? [:]
        
        // Create notification item
        let notification = NotificationItem(
            id: UUID().uuidString,
            title: title,
            body: body,
            category: notificationCategory,
            timestamp: Date(),
            transactionId: transactionId,
            metadata: metadata
        )
        
        // Handle based on category
        switch notificationCategory {
        case .transaction:
            handleTransactionNotification(notification)
        case .security:
            handleSecurityNotification(notification)
        case .account:
            handleAccountNotification(notification)
        case .marketing:
            handleMarketingNotification(notification)
        }
    }
    
    private func handleTransactionNotification(_ notification: NotificationItem) {
        if let transactionId = notification.transactionId {
            // Update transaction status in the app
            print("Handling transaction notification for ID: \(transactionId)")
            
            // Add to pending notifications if needed
            if notification.metadata["requiresAction"] as? Bool == true {
                NotificationService.shared.pendingNotifications.append(notification)
            }
        }
    }
    
    private func handleSecurityNotification(_ notification: NotificationItem) {
        // Add to pending notifications for security alerts
        NotificationService.shared.pendingNotifications.append(notification)
        
        // Update security status in the app
        if let alertType = notification.metadata["alertType"] as? String {
            print("Handling security alert: \(alertType)")
            // Handle different types of security alerts
        }
    }
    
    private func handleAccountNotification(_ notification: NotificationItem) {
        // Handle account-related notifications
        if let updateType = notification.metadata["updateType"] as? String {
            print("Handling account update: \(updateType)")
            // Handle different types of account updates
        }
    }
    
    private func handleMarketingNotification(_ notification: NotificationItem) {
        // Handle marketing notifications
        if let campaignId = notification.metadata["campaignId"] as? String {
            print("Handling marketing campaign: \(campaignId)")
            // Track marketing notification metrics
        }
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Store FCM token
        if let token = fcmToken {
            NotificationService.shared.saveFCMToken(token)
        }
    }
} 