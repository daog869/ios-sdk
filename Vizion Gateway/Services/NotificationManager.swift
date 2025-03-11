import Foundation
import UserNotifications
import UIKit
import FirebaseMessaging

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isPermissionGranted = false
    @Published var fcmToken: String?
    @Published var pendingNotifications: [NotificationItem] = []
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        checkNotificationPermission()
    }
    
    // MARK: - Permission Management
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isPermissionGranted = granted
                if granted {
                    self?.registerForRemoteNotifications()
                }
                if let error = error {
                    print("Error requesting notification permission: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isPermissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Local Notifications
    
    func scheduleLocalNotification(
        title: String,
        body: String,
        identifier: String,
        timeInterval: TimeInterval,
        repeats: Bool = false,
        category: NotificationCategory? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        if let category = category {
            content.categoryIdentifier = category.rawValue
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: repeats)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleLocalNotification(
        title: String,
        body: String,
        identifier: String,
        date: Date,
        repeats: Bool = false,
        category: NotificationCategory? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        if let category = category {
            content.categoryIdentifier = category.rawValue
        }
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Notification Categories
    
    func setupNotificationCategories() {
        let categories: Set<UNNotificationCategory> = [
            createTransactionCategory(),
            createSecurityAlertCategory(),
            createBalanceUpdateCategory()
        ]
        
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
    
    private func createTransactionCategory() -> UNNotificationCategory {
        let viewAction = UNNotificationAction(
            identifier: NotificationAction.view.rawValue,
            title: "View",
            options: .foreground
        )
        
        return UNNotificationCategory(
            identifier: NotificationCategory.transaction.rawValue,
            actions: [viewAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
    }
    
    private func createSecurityAlertCategory() -> UNNotificationCategory {
        let reviewAction = UNNotificationAction(
            identifier: NotificationAction.review.rawValue,
            title: "Review",
            options: .foreground
        )
        
        let ignoreAction = UNNotificationAction(
            identifier: NotificationAction.ignore.rawValue,
            title: "Ignore",
            options: .destructive
        )
        
        return UNNotificationCategory(
            identifier: NotificationCategory.securityAlert.rawValue,
            actions: [reviewAction, ignoreAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
    }
    
    private func createBalanceUpdateCategory() -> UNNotificationCategory {
        let viewAction = UNNotificationAction(
            identifier: NotificationAction.view.rawValue,
            title: "View Balance",
            options: .foreground
        )
        
        return UNNotificationCategory(
            identifier: NotificationCategory.balanceUpdate.rawValue,
            actions: [viewAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
    }
    
    // MARK: - Notification Handling
    
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case NotificationAction.view.rawValue:
            handleViewAction(userInfo)
        case NotificationAction.review.rawValue:
            handleReviewAction(userInfo)
        case NotificationAction.ignore.rawValue:
            handleIgnoreAction(userInfo)
        default:
            break
        }
    }
    
    private func handleViewAction(_ userInfo: [AnyHashable: Any]) {
        // Handle view action based on notification type
        if let type = userInfo["type"] as? String {
            switch type {
            case "transaction":
                if let transactionId = userInfo["transactionId"] as? String {
                    NotificationCenter.default.post(
                        name: .viewTransaction,
                        object: nil,
                        userInfo: ["transactionId": transactionId]
                    )
                }
            case "balance":
                NotificationCenter.default.post(name: .viewBalance, object: nil)
            default:
                break
            }
        }
    }
    
    private func handleReviewAction(_ userInfo: [AnyHashable: Any]) {
        if let alertId = userInfo["alertId"] as? String {
            NotificationCenter.default.post(
                name: .reviewSecurityAlert,
                object: nil,
                userInfo: ["alertId": alertId]
            )
        }
    }
    
    private func handleIgnoreAction(_ userInfo: [AnyHashable: Any]) {
        if let alertId = userInfo["alertId"] as? String {
            // Mark alert as ignored in the backend
            print("Ignored security alert: \(alertId)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Handle foreground notifications
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationResponse(response)
        completionHandler()
    }
}

// MARK: - MessagingDelegate

extension NotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        self.fcmToken = fcmToken
        
        // Send token to server
        if let token = fcmToken {
            // Update token on server
            print("FCM token: \(token)")
        }
    }
}

// MARK: - Supporting Types

enum NotificationCategory: String {
    case transaction = "TRANSACTION_CATEGORY"
    case securityAlert = "SECURITY_ALERT_CATEGORY"
    case balanceUpdate = "BALANCE_UPDATE_CATEGORY"
}

enum NotificationAction: String {
    case view = "VIEW_ACTION"
    case review = "REVIEW_ACTION"
    case ignore = "IGNORE_ACTION"
}

struct NotificationItem: Identifiable {
    let id: String
    let title: String
    let body: String
    let date: Date
    let category: NotificationCategory
    var isRead: Bool
    var userInfo: [AnyHashable: Any]
}

// MARK: - Notification Names

extension Notification.Name {
    static let viewTransaction = Notification.Name("viewTransaction")
    static let viewBalance = Notification.Name("viewBalance")
    static let reviewSecurityAlert = Notification.Name("reviewSecurityAlert")
} 