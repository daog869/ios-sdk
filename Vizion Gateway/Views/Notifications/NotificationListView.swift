import SwiftUI

struct NotificationListView: View {
    @StateObject private var notificationService = NotificationService.shared
    @State private var selectedTab = 0
    @State private var showingTransactionDetails = false
    @State private var selectedTransactionId: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom segmented control
            HStack(spacing: 0) {
                TabButton(title: "Pending", isSelected: selectedTab == 0) {
                    withAnimation { selectedTab = 0 }
                }
                
                TabButton(title: "History", isSelected: selectedTab == 1) {
                    withAnimation { selectedTab = 1 }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Tab content
            TabView(selection: $selectedTab) {
                PendingNotificationsView(
                    notifications: notificationService.pendingNotifications,
                    onTransactionTap: { transactionId in
                        selectedTransactionId = transactionId
                        showingTransactionDetails = true
                    }
                )
                .tag(0)
                
                NotificationHistoryView()
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingTransactionDetails) {
            if let transactionId = selectedTransactionId {
                NavigationStack {
                    TransactionDetailLookupView(transactionId: transactionId)
                }
            }
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .foregroundColor(isSelected ? .white : .primary)
                .background(isSelected ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pending Notifications View
struct PendingNotificationsView: View {
    let notifications: [NotificationItem]
    let onTransactionTap: (String) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if notifications.isEmpty {
                    EmptyStateView(
                        image: "bell.slash",
                        title: "No Pending Notifications",
                        message: "You're all caught up!"
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(notifications) { notification in
                        NotificationCard(notification: notification) {
                            if let transactionId = notification.transactionId {
                                onTransactionTap(transactionId)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Notification History View
struct NotificationHistoryView: View {
    @State private var notifications: [NotificationItem] = [] // In a real app, fetch from CoreData/API
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if notifications.isEmpty {
                    EmptyStateView(
                        image: "bell.slash",
                        title: "No Notification History",
                        message: "Your notification history will appear here"
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(notifications) { notification in
                        NotificationHistoryRow(notification: notification)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Notification Card
struct NotificationCard: View {
    let notification: NotificationItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    CategoryIcon(category: notification.category)
                    
                    Text(notification.title)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(timeAgo(from: notification.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(notification.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                if notification.category == .security {
                    HStack(spacing: 8) {
                        Button(action: {
                            // Handle approve action
                        }) {
                            Text("Approve")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                        
                        Button(action: {
                            // Handle decline action
                        }) {
                            Text("Decline")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification History Row
struct NotificationHistoryRow: View {
    let notification: NotificationItem
    
    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: notification.category)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text(notification.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Text(timeAgo(from: notification.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Category Icon
struct CategoryIcon: View {
    let category: NotificationCategory
    
    var iconName: String {
        switch category {
        case .transaction:
            return "creditcard.fill"
        case .security:
            return "lock.shield.fill"
        case .account:
            return "person.fill"
        case .marketing:
            return "megaphone.fill"
        }
    }
    
    var iconColor: Color {
        switch category {
        case .transaction:
            return .blue
        case .security:
            return .red
        case .account:
            return .green
        case .marketing:
            return .purple
        }
    }
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let image: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: image)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Helper Functions
func timeAgo(from date: Date) -> String {
    let calendar = Calendar.current
    let now = Date()
    let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
    
    if let day = components.day, day > 0 {
        return day == 1 ? "Yesterday" : "\(day)d ago"
    }
    
    if let hour = components.hour, hour > 0 {
        return "\(hour)h ago"
    }
    
    if let minute = components.minute, minute > 0 {
        return "\(minute)m ago"
    }
    
    return "Just now"
}

// MARK: - Transaction Detail Lookup View
struct TransactionDetailLookupView: View {
    let transactionId: String
    @State private var transaction: Transaction?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if let transaction = transaction {
                TransactionDetailView(transaction: transaction)
            } else if isLoading {
                ProgressView("Loading transaction...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("Transaction Not Found")
                        .font(.headline)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button("Dismiss") {
                        dismiss()
                    }
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            loadTransaction()
        }
    }
    
    private func loadTransaction() {
        isLoading = true
        
        Task {
            do {
                // In a real app, fetch the transaction from FirebaseManager or other data source
                let loadedTransaction = try await FirebaseManager.shared.getTransaction(id: transactionId)
                
                await MainActor.run {
                    self.transaction = loadedTransaction
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load transaction: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        NotificationListView()
    }
} 
