import SwiftUI
import SwiftData
import Charts
import Vizion_Gateway

// We need to access TransactionRow from CommonViews directly
// without trying to use module imports

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var timeRange: TimeRange = .today
    @State private var selectedPaymentType: String? = nil
    @State private var isRefreshing: Bool = false
    
    // Sample data until Firebase integration
    @State private var totalTransactions: Int = 0
    @State private var transactionVolume: Double = 0
    @State private var revenueAmount: Double = 0
    @State private var activeIntegrations: Int = 0
    
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
                    
                    // Time Range Picker
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
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
                
                // Main Statistics Cards
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    StatisticCard(
                        title: "Transactions",
                        value: "\(totalTransactions)",
                        icon: "arrow.left.arrow.right",
                        color: .blue,
                        change: "+12%"
                    )
                    
                    StatisticCard(
                        title: "Volume",
                        value: "$\(formatCurrency(transactionVolume))",
                        icon: "chart.bar.fill",
                        color: .green,
                        change: "+8.5%"
                    )
                    
                    StatisticCard(
                        title: "Revenue",
                        value: "$\(formatCurrency(revenueAmount))",
                        icon: "dollarsign.circle.fill",
                        color: .purple,
                        change: "+5.2%"
                    )
                    
                    StatisticCard(
                        title: "Integrations",
                        value: "\(activeIntegrations)",
                        icon: "link.circle.fill",
                        color: .orange,
                        change: "+2"
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
                            ForEach(getSampleTransactions()) { transaction in
                                DashboardTransactionRow(transaction: transaction)
                                
                                if transaction.id != getSampleTransactions().last?.id {
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
                            ForEach(getSampleIntegrations()) { integration in
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
                
                // Sandbox Disclaimer
                if let selectedEnvironment = UserDefaults.standard.string(forKey: "environment"),
                   selectedEnvironment == AppEnvironment.sandbox.rawValue {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        
                        Text("You are currently in Sandbox mode. No real transactions are being processed.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            loadDashboardData()
        }
        .onChange(of: timeRange) { _, _ in
            loadDashboardData()
        }
        .refreshable {
            refreshDashboard()
        }
    }
    
    // MARK: - Methods
    
    private func loadDashboardData() {
        // This will be replaced with Firebase data loading
        // For now, load sample data
        
        totalTransactions = Int.random(in: 800..<1500)
        transactionVolume = Double.random(in: 50000..<150000)
        revenueAmount = transactionVolume * 0.025
        activeIntegrations = Int.random(in: 5..<15)
        
        // Generate chart data based on time range
        transactionData = generateTransactionData(for: timeRange)
    }
    
    private func refreshDashboard() {
        withAnimation {
            isRefreshing = true
        }
        
        // Simulate network request delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            loadDashboardData()
            
            withAnimation {
                isRefreshing = false
            }
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
    
    // MARK: - Sample Data Generation
    
    private func getSampleTransactions() -> [TransactionData] {
        return [
            TransactionData(id: "TX123456", merchantName: "Coffee Shop", amount: 25.50, status: .completed, timestamp: Date()),
            TransactionData(id: "TX123457", merchantName: "Electronics Store", amount: 899.99, status: .completed, timestamp: Date().addingTimeInterval(-3600)),
            TransactionData(id: "TX123458", merchantName: "Grocery Market", amount: 156.78, status: .pending, timestamp: Date().addingTimeInterval(-7200)),
            TransactionData(id: "TX123459", merchantName: "Online Shop", amount: 49.99, status: .failed, timestamp: Date().addingTimeInterval(-14400)),
            TransactionData(id: "TX123460", merchantName: "Restaurant", amount: 87.65, status: .completed, timestamp: Date().addingTimeInterval(-28800))
        ]
    }
    
    private func getSampleIntegrations() -> [IntegrationData] {
        return [
            IntegrationData(id: "INT001", name: "E-commerce Platform", status: .active, apiVersion: "v2", lastActive: Date()),
            IntegrationData(id: "INT002", name: "Mobile Payments App", status: .active, apiVersion: "v1", lastActive: Date().addingTimeInterval(-1800)),
            IntegrationData(id: "INT003", name: "Subscription Service", status: .active, apiVersion: "v2", lastActive: Date().addingTimeInterval(-3600)),
            IntegrationData(id: "INT004", name: "POS System", status: .inactive, apiVersion: "v1", lastActive: Date().addingTimeInterval(-86400))
        ]
    }
    
    private func generateTransactionData(for timeRange: TimeRange) -> [TransactionDataPoint] {
        var dataPoints: [TransactionDataPoint] = []
        let now = Date()
        
        let (dataPointCount, timeInterval) = timeRange.chartParameters
        
        for i in 0..<dataPointCount {
            let timestamp = now.addingTimeInterval(-Double(dataPointCount - i - 1) * timeInterval)
            
            // Generate a somewhat realistic curve with some randomness
            let baseValue = Double.random(in: 8000..<12000)
            let hourOfDay = Calendar.current.component(.hour, from: timestamp)
            
            // Transactions are higher during business hours
            let timeMultiplier = (hourOfDay >= 9 && hourOfDay <= 17) ? Double.random(in: 1.2...1.5) : Double.random(in: 0.6...0.9)
            
            // Weekend dip
            let weekday = Calendar.current.component(.weekday, from: timestamp)
            let weekendMultiplier = (weekday == 1 || weekday == 7) ? 0.7 : 1.0
            
            // Calculate final value with some noise
            let value = baseValue * timeMultiplier * weekendMultiplier * Double.random(in: 0.95...1.05)
            
            dataPoints.append(TransactionDataPoint(id: UUID(), timestamp: timestamp, amount: value))
        }
        
        return dataPoints
    }
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
    let transaction: TransactionData
    
    var body: some View {
        HStack {
            Text(transaction.id)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(transaction.merchantName)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("$\(String(format: "%.2f", transaction.amount))")
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
    
    private func statusColor(_ status: DashboardTransactionStatus) -> Color {
        switch status {
        case .completed:
            return .green
        case .pending:
            return .orange
        case .failed:
            return .red
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

struct TransactionData: Identifiable {
    let id: String
    let merchantName: String
    let amount: Double
    let status: DashboardTransactionStatus
    let timestamp: Date
}

// Dashboard-specific enums to avoid ambiguity with model enums
enum DashboardTransactionStatus: String {
    case completed = "Completed"
    case pending = "Pending"
    case failed = "Failed"
}

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