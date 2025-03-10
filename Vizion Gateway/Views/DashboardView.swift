import SwiftUI
import SwiftData
import Charts
import FirebaseFirestore
import FirebaseAuth

// We need to access TransactionRow from CommonViews directly
// without trying to use module imports

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var timeRange: TimeRange = .today
    @State private var selectedPaymentType: String? = nil
    @State private var isRefreshing: Bool = false
    
    // Dashboard data from Firebase
    @State private var dashboardData: DashboardData?
    @State private var transactions: [Transaction] = []
    @State private var integrations: [IntegrationData] = []
    @State private var isLoading = true
    @State private var error: Error?
    
    // Charts data
    @State private var transactionData: [TransactionDataPoint] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with Time Range Selector
                HStack {
                    Text("Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Time Range Picker - Breaking up the complex expression
                    VStack {
                        Picker("Time Range", selection: $timeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .frame(width: 300)
                    
                    // Refresh Button
                    Button(action: {
                        refreshDashboard()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    }
                    .padding(.leading, 8)
                    .disabled(isRefreshing)
                }
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Main Statistics Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        StatisticCard(
                            title: "Transactions",
                            value: "\(dashboardData?.totalTransactions ?? 0)",
                            icon: "arrow.left.arrow.right",
                            color: .blue,
                            change: calculateChange(for: .transactions)
                        )
                        
                        StatisticCard(
                            title: "Volume",
                            value: "$\(formatCurrency(dashboardData?.transactionVolume ?? 0))",
                            icon: "chart.bar.fill",
                            color: .green,
                            change: calculateChange(for: .volume)
                        )
                        
                        StatisticCard(
                            title: "Revenue",
                            value: "$\(formatCurrency(dashboardData?.revenueAmount ?? 0))",
                            icon: "dollarsign.circle.fill",
                            color: .purple,
                            change: calculateChange(for: .revenue)
                        )
                        
                        StatisticCard(
                            title: "Integrations",
                            value: "\(dashboardData?.activeIntegrations ?? 0)",
                            icon: "link.circle.fill",
                            color: .orange,
                            change: calculateChange(for: .integrations)
                        )
                    }
                    .padding(.horizontal)
                    
                    // Transaction Chart
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Transaction Overview")
                            .font(.headline)
                        
                        // Chart container with border
                        VStack(alignment: .leading, spacing: 12) {
                            if !transactionData.isEmpty {
                                Chart {
                                    ForEach(transactionData) { dataPoint in
                                        LineMark(
                                            x: .value("Time", dataPoint.timestamp),
                                            y: .value("Amount", dataPoint.amount)
                                        )
                                        .foregroundStyle(Color.blue.gradient)
                                        
                                        AreaMark(
                                            x: .value("Time", dataPoint.timestamp),
                                            y: .value("Amount", dataPoint.amount)
                                        )
                                        .foregroundStyle(Color.blue.opacity(0.1).gradient)
                                    }
                                }
                                .frame(height: 200)
                            } else {
                                Text("No transaction data available")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 200)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    
                    HStack(alignment: .top, spacing: 16) {
                        // Recent Transactions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Transactions")
                                .font(.headline)
                            
                            VStack(spacing: 0) {
                                // Headers
                                HStack {
                                    Text("ID")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 80, alignment: .leading)
                                    
                                    Text("Merchant")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Text("Amount")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 100, alignment: .trailing)
                                    
                                    Text("Status")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 100, alignment: .trailing)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(UIColor.systemGray6))
                                
                                Divider()
                                
                                // Sample transactions (will be replaced with real data from Firebase)
                                ForEach(transactions) { transaction in
                                    DashboardTransactionRow(transaction: transaction)
                                    
                                    if transaction.id != transactions.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .background(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // API Integration Status
                        VStack(alignment: .leading, spacing: 16) {
                            Text("API Integrations")
                                .font(.headline)
                            
                            VStack(spacing: 8) {
                                ForEach(integrations) { integration in
                                    IntegrationStatusCard(integration: integration)
                                }
                            }
                            .background(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .task {
            await loadDashboardData()
        }
        .onChange(of: timeRange) { _, _ in
            Task {
                await loadDashboardData()
            }
        }
        .refreshable {
            await loadDashboardData()
        }
    }
    
    // MARK: - Methods
    
    private func loadDashboardData() async {
        isLoading = true
        isRefreshing = true
        
        do {
            // Load dashboard data from Firebase
            dashboardData = try await FirebaseManager.shared.getDashboardData()
            
            // Load transactions using the standard getTransactions method
            transactions = try await FirebaseManager.shared.getTransactions(limit: 5)
            
            // Instead of getting API keys directly, we'll update the integrations from dashboard data
            integrations = createIntegrationsFromDashboard()
            
            // Update transaction chart data
            await updateTransactionData()
        } catch {
            self.error = error
            print("Error loading dashboard data: \(error.localizedDescription)")
        }
        
        isLoading = false
        isRefreshing = false
    }
    
    // Create integrations data from dashboard data
    private func createIntegrationsFromDashboard() -> [IntegrationData] {
        // Create default integrations if dashboard data isn't available yet
        guard let dashboard = dashboardData else {
            return []
        }
        
        // Create some basic integration data based on dashboard activeIntegrations count
        var result: [IntegrationData] = []
        
        // If there are active integrations reported in the dashboard data, create entries for them
        for i in 0..<dashboard.activeIntegrations {
            result.append(
                IntegrationData(
                    id: "integration-\(i+1)",
                    name: "API Integration \(i+1)",
                    status: .active,
                    apiVersion: "v1",
                    lastActive: Date().addingTimeInterval(-Double(i) * 3600)
                )
            )
        }
        
        return result
    }
    
    private func refreshDashboard() {
        Task {
            await loadDashboardData()
        }
    }
    
    private func updateTransactionData() async {
        do {
            // Get historical transaction data from Firebase based on selected time range
            let historicalTransactions = try await FirebaseManager.shared.getHistoricalTransactions(for: timeRange)
            
            if historicalTransactions.isEmpty {
                // If no transactions exist, show empty chart data
                transactionData = []
            } else {
                // Create data points from real transactions
                transactionData = historicalTransactions.map { transaction in
                    TransactionDataPoint(
                        id: UUID(),
                        timestamp: transaction.timestamp,
                        amount: NSDecimalNumber(decimal: transaction.amount).doubleValue
                    )
                }
            }
        } catch {
            print("Error updating transaction data: \(error.localizedDescription)")
            transactionData = []
        }
    }
    
    private func calculateChange(for metric: DashboardMetric) -> String {
        guard let dashboardData = dashboardData else { return "+0%" }
        
        let changeValue: Double
        
        switch metric {
        case .transactions:
            changeValue = dashboardData.transactionChange
        case .volume:
            changeValue = dashboardData.volumeChange
        case .revenue:
            changeValue = dashboardData.revenueChange
        case .integrations:
            changeValue = dashboardData.integrationChange
        }
        
        let prefix = changeValue >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", changeValue))%"
    }
    
    enum DashboardMetric {
        case transactions, volume, revenue, integrations
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
    
    // MARK: - Sample Data Generation
    
    // No sample data generation needed anymore
}

// MARK: - Supporting Views

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let change: String?
    
    init(title: String, value: String, icon: String, color: Color, change: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.change = change
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                
                Spacer()
                
                if let change = change {
                    Text(change)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(change.hasPrefix("+") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .foregroundStyle(change.hasPrefix("+") ? Color.green : Color.red)
                        .cornerRadius(4)
                }
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct IntegrationStatusCard: View {
    let integration: IntegrationData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(integration.name)
                    .font(.headline)
                
                Text("API v\(integration.apiVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Last active: \(timeAgo(from: integration.lastActive))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Status indicator
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Circle()
                        .fill(integration.status == .active ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(integration.status.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(integration.status == .active ? Color.green : Color.red)
                }
                
                if integration.status == .active {
                    Text("Receiving webhooks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct DashboardTransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            Text(transaction.id.prefix(8))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(transaction.merchantName ?? "Unknown Merchant")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: transaction.amount).doubleValue))")
                .frame(width: 100, alignment: .trailing)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor(transaction.status))
                    .frame(width: 8, height: 8)
                
                Text(transaction.status.rawValue)
                    .foregroundStyle(statusColor(transaction.status))
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
    
    private func statusColor(_ status: TransactionStatus) -> Color {
        switch status {
        case .completed:
            return .green
        case .pending, .processing:
            return .orange
        case .failed, .disputed, .cancelled:
            return .red
        case .refunded:
            return .blue
        }
    }
}

// MARK: - Data Models

// TimeRange has been moved to Models.swift
// ... existing code ...

struct TransactionDataPoint: Identifiable {
    let id: UUID
    let timestamp: Date
    let amount: Double
}

// IntegrationData structure
struct IntegrationData: Identifiable {
    let id: String
    let name: String
    let status: IntegrationStatus
    let apiVersion: String
    let lastActive: Date
}

enum IntegrationStatus: String {
    case active = "Active"
    case inactive = "Inactive"
}

// MARK: - FirebaseManager Extensions

// Get historical transactions by date range
extension FirebaseManager {
    func getHistoricalTransactions(for timeRange: TimeRange) async throws -> [Transaction] {
        // Get the start date based on the time range
        let startDate: Date
        let endDate = Date()
        
        switch timeRange {
        case .today:
            startDate = Calendar.current.startOfDay(for: Date())
        case .week:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month:
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .year:
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        }
        
        // Get transactions and filter by date client-side
        let allTransactions = try await getTransactions(limit: 100)
        return allTransactions.filter { transaction in
            return transaction.timestamp >= startDate && transaction.timestamp <= endDate
        }
    }
}

// Preview provider
#Preview {
    DashboardView()
        .modelContainer(for: Transaction.self, inMemory: true)
} 
