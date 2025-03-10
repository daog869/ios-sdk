import Foundation
import UserNotifications
import FirebaseMessaging
import SwiftUI

// Enum for notification categories
enum NotificationCategory: String {
    case transaction = "TRANSACTION"
    case security = "SECURITY"
    case account = "ACCOUNT"
    case marketing = "MARKETING"
    
    var identifier: String {
        return rawValue
    }
}

// Enum for notification actions
enum NotificationAction: String {
    case view = "VIEW"
    case approve = "APPROVE"
    case decline = "DECLINE"
    
    var identifier: String {
        return rawValue
    }
}

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isPermissionGranted = false
    @Published var pendingNotifications: [NotificationItem] = []
    
    // User notification preferences
    @AppStorage("notifyPayments") private var notifyPayments = true
    @AppStorage("notifyRefunds") private var notifyRefunds = true
    @AppStorage("notifyDisputes") private var notifyDisputes = true
    @AppStorage("notifySecurityAlerts") private var notifySecurityAlerts = true
    @AppStorage("notifyPromotions") private var notifyPromotions = false
    @AppStorage("notificationSound") private var notificationSound = true
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        
        // Set notification delegate
        notificationCenter.delegate = self
        
        // Register notification categories with actions
        registerNotificationCategories()
        
        // Check notification permission status
        checkPermissionStatus()
    }
    
    // MARK: - Setup Methods
    
    private func registerNotificationCategories() {
        // Transaction category with view action
        let viewAction = UNNotificationAction(
            identifier: NotificationAction.view.identifier,
            title: "View",
            options: .foreground
        )
        
        // Transaction category (for payments, refunds, etc.)
        let transactionCategory = UNNotificationCategory(
            identifier: NotificationCategory.transaction.identifier,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Security category with approve/decline actions
        let approveAction = UNNotificationAction(
            identifier: NotificationAction.approve.identifier,
            title: "Approve",
            options: [.authenticationRequired, .foreground]
        )
        
        let declineAction = UNNotificationAction(
            identifier: NotificationAction.decline.identifier,
            title: "Decline",
            options: [.authenticationRequired, .destructive, .foreground]
        )
        
        let securityCategory = UNNotificationCategory(
            identifier: NotificationCategory.security.identifier,
            actions: [approveAction, declineAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Account category
        let accountCategory = UNNotificationCategory(
            identifier: NotificationCategory.account.identifier,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Marketing category
        let marketingCategory = UNNotificationCategory(
            identifier: NotificationCategory.marketing.identifier,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register all categories
        notificationCenter.setNotificationCategories([
            transactionCategory,
            securityCategory,
            accountCategory,
            marketingCategory
        ])
    }
    
    // MARK: - Permission Methods
    
    func requestPermission() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        
        notificationCenter.requestAuthorization(options: options) { granted, error in
            DispatchQueue.main.async {
                self.isPermissionGranted = granted
                
                if granted {
                    // Register for remote notifications
                    UIApplication.shared.registerForRemoteNotifications()
                    
                    // Subscribe to topics based on user preferences
                    self.updateTopicSubscriptions()
                }
                
                if let error = error {
                    print("Error requesting notification permission: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func checkPermissionStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isPermissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Topic Subscription Methods
    
    func updateTopicSubscriptions() {
        // Payment notifications
        self.toggleTopic("payments", subscribe: notifyPayments)
        
        // Refund notifications
        self.toggleTopic("refunds", subscribe: notifyRefunds)
        
        // Dispute notifications
        self.toggleTopic("disputes", subscribe: notifyDisputes)
        
        // Security notifications
        self.toggleTopic("security", subscribe: notifySecurityAlerts)
        
        // Promotion notifications
        self.toggleTopic("promotions", subscribe: notifyPromotions)
    }
    
    private func toggleTopic(_ topic: String, subscribe: Bool) {
        if subscribe {
            Messaging.messaging().subscribe(toTopic: topic) { error in
                if let error = error {
                    print("Error subscribing to \(topic): \(error.localizedDescription)")
                } else {
                    print("Subscribed to \(topic)")
                }
            }
        } else {
            Messaging.messaging().unsubscribe(fromTopic: topic) { error in
                if let error = error {
                    print("Error unsubscribing from \(topic): \(error.localizedDescription)")
                } else {
                    print("Unsubscribed from \(topic)")
                }
            }
        }
    }
    
    // MARK: - Local Notification Methods
    
    func scheduleLocalNotification(title: String, body: String, category: NotificationCategory, userInfo: [String: Any] = [:]) {
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category.identifier
        content.userInfo = userInfo
        
        if notificationSound {
            content.sound = .default
        }
        
        // Create a time trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create a notification request
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        // Add the request to the notification center
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - High-Value Transaction Notification
    
    func notifyHighValueTransaction(transaction: Transaction) {
        let threshold: Decimal = 500.0 // threshold for high-value transactions
        
        if transaction.amount > threshold {
            // Store the high-value transaction for merchant approval
            let notificationItem = NotificationItem(
                id: UUID().uuidString,
                title: "High-Value Transaction",
                body: "Transaction of \(formatAmount(transaction.amount, currency: transaction.currency)) requires your approval",
                category: .security,
                timestamp: Date(),
                transactionId: transaction.id,
                metadata: ["amount": transaction.amount, "currency": transaction.currency]
            )
            
            pendingNotifications.append(notificationItem)
            
            // Send a push notification to the merchant
            scheduleLocalNotification(
                title: notificationItem.title,
                body: notificationItem.body,
                category: .security,
                userInfo: ["transactionId": transaction.id]
            )
        }
    }
    
    // MARK: - Transaction Event Notifications
    
    func notifyPaymentReceived(transaction: Transaction) {
        guard notifyPayments else { return }
        
        let title = "Payment Received"
        let body = "You received a payment of \(formatAmount(transaction.amount, currency: transaction.currency)) from \(transaction.customerName ?? "a customer")"
        
        scheduleLocalNotification(
            title: title,
            body: body,
            category: .transaction,
            userInfo: ["transactionId": transaction.id]
        )
    }
    
    func notifyPaymentSent(transaction: Transaction) {
        guard notifyPayments else { return }
        
        let title = "Payment Sent"
        let body = "Your payment of \(formatAmount(transaction.amount, currency: transaction.currency)) to \(transaction.merchantName) was successful"
        
        scheduleLocalNotification(
            title: title,
            body: body,
            category: .transaction,
            userInfo: ["transactionId": transaction.id]
        )
    }
    
    func notifyRefund(transaction: Transaction) {
        guard notifyRefunds else { return }
        
        let title = "Refund Processed"
        let body = "A refund of \(formatAmount(transaction.amount, currency: transaction.currency)) from \(transaction.merchantName) has been processed"
        
        scheduleLocalNotification(
            title: title,
            body: body,
            category: .transaction,
            userInfo: ["transactionId": transaction.id]
        )
    }
    
    func notifyDispute(transaction: Transaction) {
        guard notifyDisputes else { return }
        
        let title = "Transaction Disputed"
        let body = "A transaction of \(formatAmount(transaction.amount, currency: transaction.currency)) has been disputed"
        
        scheduleLocalNotification(
            title: title,
            body: body,
            category: .transaction,
            userInfo: ["transactionId": transaction.id]
        )
    }
    
    // MARK: - Security Notifications
    
    func notifyLoginAttempt(successful: Bool, location: String) {
        guard notifySecurityAlerts else { return }
        
        let title = successful ? "New Login" : "Failed Login Attempt"
        let body = successful ? "New login detected from \(location)" : "Failed login attempt from \(location)"
        
        scheduleLocalNotification(
            title: title,
            body: body,
            category: .security
        )
    }
    
    func notifyAPIKeyCreated(apiKey: APIKey) {
        guard notifySecurityAlerts else { return }
        
        let title = "New API Key Created"
        let body = "A new API key '\(apiKey.name)' has been created"
        
        scheduleLocalNotification(
            title: title,
            body: body,
            category: .security,
            userInfo: ["apiKeyId": apiKey.id]
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatAmount(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) \(currency)"
    }
    
    // MARK: - Preference Getters/Setters
    
    func setNotifyPayments(_ value: Bool) {
        notifyPayments = value
        updateTopicSubscriptions()
    }
    
    func setNotifyRefunds(_ value: Bool) {
        notifyRefunds = value
        updateTopicSubscriptions()
    }
    
    func setNotifyDisputes(_ value: Bool) {
        notifyDisputes = value
        updateTopicSubscriptions()
    }
    
    func setNotifySecurityAlerts(_ value: Bool) {
        notifySecurityAlerts = value
        updateTopicSubscriptions()
    }
    
    func setNotifyPromotions(_ value: Bool) {
        notifyPromotions = value
        updateTopicSubscriptions()
    }
    
    func setNotificationSound(_ value: Bool) {
        notificationSound = value
    }
    
    // Getters
    func getNotifyPayments() -> Bool { return notifyPayments }
    func getNotifyRefunds() -> Bool { return notifyRefunds }
    func getNotifyDisputes() -> Bool { return notifyDisputes }
    func getNotifySecurityAlerts() -> Bool { return notifySecurityAlerts }
    func getNotifyPromotions() -> Bool { return notifyPromotions }
    func getNotificationSound() -> Bool { return notificationSound }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    // Handle foreground notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification actions
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        let actionIdentifier = response.actionIdentifier
        
        switch categoryIdentifier {
        case NotificationCategory.transaction.identifier:
            handleTransactionNotificationResponse(userInfo: userInfo, actionIdentifier: actionIdentifier)
            
        case NotificationCategory.security.identifier:
            handleSecurityNotificationResponse(userInfo: userInfo, actionIdentifier: actionIdentifier)
            
        case NotificationCategory.account.identifier:
            handleAccountNotificationResponse(userInfo: userInfo, actionIdentifier: actionIdentifier)
            
        case NotificationCategory.marketing.identifier:
            handleMarketingNotificationResponse(userInfo: userInfo, actionIdentifier: actionIdentifier)
            
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleTransactionNotificationResponse(userInfo: [AnyHashable: Any], actionIdentifier: String) {
        if actionIdentifier == NotificationAction.view.identifier {
            if let transactionId = userInfo["transactionId"] as? String {
                // Open transaction details
                print("Viewing transaction: \(transactionId)")
                
                // In a real app, you would navigate to the transaction details view
                // NavigationService.shared.navigateToTransaction(id: transactionId)
            }
        }
    }
    
    private func handleSecurityNotificationResponse(userInfo: [AnyHashable: Any], actionIdentifier: String) {
        switch actionIdentifier {
        case NotificationAction.approve.identifier:
            if let transactionId = userInfo["transactionId"] as? String {
                // Approve the high-value transaction
                print("Approving transaction: \(transactionId)")
                
                // In a real app, you would call your API to approve the transaction
                // TransactionService.shared.approveTransaction(id: transactionId)
            }
            
        case NotificationAction.decline.identifier:
            if let transactionId = userInfo["transactionId"] as? String {
                // Decline the high-value transaction
                print("Declining transaction: \(transactionId)")
                
                // In a real app, you would call your API to decline the transaction
                // TransactionService.shared.declineTransaction(id: transactionId)
            }
            
        case NotificationAction.view.identifier:
            // View security alert details
            print("Viewing security alert")
            
            // In a real app, you would navigate to the security alerts view
            // NavigationService.shared.navigateToSecurityAlerts()
            
        default:
            break
        }
    }
    
    private func handleAccountNotificationResponse(userInfo: [AnyHashable: Any], actionIdentifier: String) {
        if actionIdentifier == NotificationAction.view.identifier {
            // View account update
            print("Viewing account update")
            
            // In a real app, you would navigate to the account view
            // NavigationService.shared.navigateToAccount()
        }
    }
    
    private func handleMarketingNotificationResponse(userInfo: [AnyHashable: Any], actionIdentifier: String) {
        if actionIdentifier == NotificationAction.view.identifier {
            if let url = userInfo["url"] as? String, let promoUrl = URL(string: url) {
                // Open promotion URL
                // In a real app, you would open the URL or navigate to the promotion view
                print("Opening promotion URL: \(promoUrl)")
                
                UIApplication.shared.open(promoUrl)
            }
        }
    }
}

// MARK: - Models

struct NotificationItem: Identifiable {
    let id: String
    let title: String
    let body: String
    let category: NotificationCategory
    let timestamp: Date
    let transactionId: String?
    let metadata: [String: Any]
    
    init(id: String, title: String, body: String, category: NotificationCategory, timestamp: Date, transactionId: String? = nil, metadata: [String: Any] = [:]) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
        self.timestamp = timestamp
        self.transactionId = transactionId
        self.metadata = metadata
    }
}

// MARK: - FCM Token Management

extension NotificationService {
    func saveFCMToken(_ token: String) {
        // Save the token to UserDefaults
        UserDefaults.standard.set(token, forKey: "fcmToken")
        
        // Send the token to your backend
        uploadFCMTokenToServer(token)
    }
    
    private func uploadFCMTokenToServer(_ token: String) {
        // In a real app, send the token to your server
        // This is a placeholder implementation
        
        // Get the current user ID
        guard let userId = AuthenticationManager.shared.currentUser?.id else {
            return
        }
        
        // Create the request body
        let body: [String: Any] = [
            "userId": userId,
            "token": token,
            "platform": "iOS",
            "deviceInfo": UIDevice.current.modelName
        ]
        
        // Send the token to your server
        print("Would upload FCM token to server: \(body)")
        
        // In a real implementation, you would make a network request to your server
        // APIService.shared.updateDeviceToken(userId: userId, token: token)
    }
}

// Helper extension for getting device model name
extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
} 