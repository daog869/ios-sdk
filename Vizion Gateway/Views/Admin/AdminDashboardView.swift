import SwiftUI
import SwiftData
import Charts

struct AdminDashboardView: View {
    @State private var timeRange: TimeRange = .month
    @State private var selectedDataPoint: DataPoint?
    @State private var dashboardData: DashboardData?
    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        List {
            if isLoading {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            MetricCard(
                                title: "Total Revenue",
                                value: (dashboardData?.revenueAmount ?? 0).formatted(.currency(code: "XCD")),
                                trend: calculateTrend(for: .revenue),
                                trendUp: true
                            )
                            
                            MetricCard(
                                title: "Transaction Count",
                                value: "\(dashboardData?.totalTransactions ?? 0)",
                                trend: calculateTrend(for: .transactions),
                                trendUp: true
                            )
                            
                            MetricCard(
                                title: "Success Rate",
                                value: "\(calculateSuccessRate())%",
                                trend: calculateTrend(for: .successRate),
                                trendUp: true
                            )
                            
                            MetricCard(
                                title: "Average Value",
                                value: calculateAverageValue().formatted(.currency(code: "XCD")),
                                trend: calculateTrend(for: .averageValue),
                                trendUp: true
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                Section("Revenue Trends") {
                    RevenueTrendChart(transactions: transactions)
                        .frame(height: 300)
                }
                
                Section("Recent Transactions") {
                    ForEach(transactions.prefix(5)) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                    
                    NavigationLink("View All Transactions") {
                        TransactionMonitoringView()
                    }
                }
                
                Section("System Health") {
                    HStack {
                        Label("API Status", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("Operational")
                    }
                    
                    HStack {
                        Label("Bank Connection", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("Connected")
                    }
                    
                    HStack {
                        Label("Webhook Service", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("Degraded")
                    }
                }
            }
        }
        .navigationTitle("Dashboard")
        .task {
            await loadDashboardData()
        }
        .refreshable {
            await loadDashboardData()
        }
    }
    
    private func loadDashboardData() async {
        isLoading = true
        
        do {
            dashboardData = try await FirebaseManager.shared.getDashboardData()
            transactions = try await FirebaseManager.shared.getTransactions(limit: 100)
        } catch {
            self.error = error
            print("Error loading dashboard data: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func calculateSuccessRate() -> String {
        let completed = Double(transactions.filter { $0.status == .completed }.count)
        let total = Double(transactions.count)
        guard total > 0 else { return "0" }
        return String(format: "%.1f", (completed / total) * 100)
    }
    
    private func calculateAverageValue() -> Decimal {
        guard !transactions.isEmpty else { return 0 }
        let total = transactions.reduce(Decimal(0)) { $0 + $1.amount }
        return total / Decimal(transactions.count)
    }
    
    private func calculateTrend(for metric: DashboardMetric) -> String {
        // Calculate trends based on historical data from Firebase
        // This would compare current period with previous period
        return "+0%" // Placeholder
    }
    
    enum DashboardMetric {
        case revenue, transactions, successRate, averageValue
    }
}

// Preview provider
#Preview {
    AdminDashboardView()
        .modelContainer(for: Transaction.self, inMemory: true)
} 