import SwiftUI
import Firebase

struct VizionGatewayApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var notificationService = NotificationService.shared
    @State private var showNotifications = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationService)
                .sheet(isPresented: $showNotifications) {
                    NavigationView {
                        NotificationListView()
                    }
                }
                .onAppear {
                    // Request notification permissions if not already granted
                    if !notificationService.isPermissionGranted {
                        notificationService.requestPermission()
                    }
                    
                    // Reset badge count when app opens
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }
                .onChange(of: notificationService.pendingNotifications.count) { newCount in
                    // Update app badge count
                    UIApplication.shared.applicationIconBadgeNumber = newCount
                }
        }
    }
}

// Add notification-related toolbar items to any view
struct NotificationToolbarModifier: ViewModifier {
    @Binding var showNotifications: Bool
    @StateObject private var notificationService = NotificationService.shared
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NotificationBarButton(showNotifications: $showNotifications)
                }
            }
    }
}

extension View {
    func withNotificationToolbar(showNotifications: Binding<Bool>) -> some View {
        modifier(NotificationToolbarModifier(showNotifications: showNotifications))
    }
} 