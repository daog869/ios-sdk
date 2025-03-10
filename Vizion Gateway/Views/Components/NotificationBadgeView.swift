import SwiftUI

struct NotificationBadgeView: View {
    @StateObject private var notificationService = NotificationService.shared
    
    var body: some View {
        TabView {
            // Your existing tab views...
            
            NotificationListView()
                .tabItem {
                    Label("Notifications", systemImage: "bell.fill")
                }
                .badge(notificationService.pendingNotifications.count)
        }
    }
}

// Custom badge modifier for any view
struct NotificationBadgeModifier: ViewModifier {
    let count: Int
    
    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.red)
                    .clipShape(Circle())
                    .offset(x: 10, y: -10)
            }
        }
    }
}

extension View {
    func notificationBadge(count: Int) -> some View {
        modifier(NotificationBadgeModifier(count: count))
    }
}

// Example usage in a navigation bar button
struct NotificationBarButton: View {
    @StateObject private var notificationService = NotificationService.shared
    @Binding var showNotifications: Bool
    
    var body: some View {
        Button {
            showNotifications.toggle()
        } label: {
            Image(systemName: "bell.fill")
                .notificationBadge(count: notificationService.pendingNotifications.count)
        }
    }
}

#Preview {
    NotificationBadgeView()
} 