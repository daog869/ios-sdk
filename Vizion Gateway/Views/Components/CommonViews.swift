import SwiftUI
import SwiftData

struct MetricCard: View {
    let title: String
    let value: String
    var trend: String?
    var trendUp: Bool?
    var icon: String?
    var color: Color?
    
    init(title: String, value: String, trend: String? = nil, trendUp: Bool? = nil) {
        self.title = title
        self.value = value
        self.trend = trend
        self.trendUp = trendUp
    }
    
    init(title: String, value: String, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let icon = icon {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color ?? .primary)
                    
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color ?? .primary)
            
            if let trend = trend, let trendUp = trendUp {
                HStack {
                    Image(systemName: trendUp ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(trendUp ? .green : .red)
                    Text(trend)
                        .font(.caption)
                        .foregroundStyle(trendUp ? .green : .red)
                }
            }
        }
        .frame(width: 200)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusBadge: View {
    let status: TransactionStatus
    
    var color: Color {
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
            return .yellow
        case .cancelled:
            return .gray
        }
    }
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(transaction.merchantName)
                        .font(.headline)
                    Text("ID: \(String(describing: transaction.id).prefix(8))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(transaction.amount.formatted(.currency(code: "XCD")))
                    .font(.headline)
            }
            
            HStack {
                StatusBadge(status: transaction.status)
                
                Text(transaction.paymentMethod.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.gray.opacity(0.2))
                    .clipShape(Capsule())
                
                Spacer()
                
                Text(transaction.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
} 