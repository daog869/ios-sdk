import SwiftUI

struct StatusBadge: View {
    let status: TransactionStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    var statusColor: Color {
        switch status {
        case .pending:
            return .orange
        case .processing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .refunded:
            return .purple
        case .disputed:
            return .pink
        case .cancelled:
            return .gray
        }
    }
} 