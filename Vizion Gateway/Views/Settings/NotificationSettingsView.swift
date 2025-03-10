import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingPermissionAlert = false
    
    var body: some View {
        Form {
            Section {
                if !notificationService.isPermissionGranted {
                    Button(action: {
                        notificationService.requestPermission()
                    }) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.red)
                            Text("Enable Push Notifications")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            
            Section(header: Text("Transaction Notifications")) {
                Toggle("Payment Activity", isOn: Binding(
                    get: { notificationService.getNotifyPayments() },
                    set: { notificationService.setNotifyPayments($0) }
                ))
                .onChange(of: notificationService.getNotifyPayments()) { newValue in
                    if newValue && !notificationService.isPermissionGranted {
                        showingPermissionAlert = true
                    }
                }
                
                Toggle("Refunds", isOn: Binding(
                    get: { notificationService.getNotifyRefunds() },
                    set: { notificationService.setNotifyRefunds($0) }
                ))
                
                Toggle("Disputes", isOn: Binding(
                    get: { notificationService.getNotifyDisputes() },
                    set: { notificationService.setNotifyDisputes($0) }
                ))
            }
            
            Section(header: Text("Security Notifications")) {
                Toggle("Security Alerts", isOn: Binding(
                    get: { notificationService.getNotifySecurityAlerts() },
                    set: { notificationService.setNotifySecurityAlerts($0) }
                ))
                .tint(.red)
            }
            
            Section(header: Text("Marketing")) {
                Toggle("Promotions and Updates", isOn: Binding(
                    get: { notificationService.getNotifyPromotions() },
                    set: { notificationService.setNotifyPromotions($0) }
                ))
            }
            
            Section(header: Text("Sound")) {
                Toggle("Notification Sound", isOn: Binding(
                    get: { notificationService.getNotificationSound() },
                    set: { notificationService.setNotificationSound($0) }
                ))
            }
        }
        .navigationTitle("Notifications")
        .alert("Enable Notifications", isPresented: $showingPermissionAlert) {
            Button("Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To receive notifications, please enable them in Settings.")
        }
    }
}

#Preview {
    NavigationView {
        NotificationSettingsView()
    }
} 