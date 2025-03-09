import SwiftUI
import SwiftData
import Charts

struct AdminDashboardView: View {
    @Query private var transactions: [Transaction]
    @State private var timeRange: TimeRange = .month
    @State private var selectedDataPoint: DataPoint?
    
    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        MetricCard(
                            title: "Total Revenue",
                            value: totalRevenue.formatted(.currency(code: "XCD")),
                            trend: "+12.5%",
                            trendUp: true
                        )
                        
                        MetricCard(
                            title: "Transaction Count",
                            value: "\(transactions.count)",
                            trend: "+5.2%",
                            trendUp: true
                        )
                        
                        MetricCard(
                            title: "Success Rate",
                            value: "\(calculateSuccessRate())%",
                            trend: "-0.5%",
                            trendUp: false
                        )
                        
                        MetricCard(
                            title: "Average Value",
                            value: averageTransactionValue.formatted(.currency(code: "XCD")),
                            trend: "+2.3%",
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
        .navigationTitle("Dashboard")
    }
    
    private var totalRevenue: Decimal {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    private var averageTransactionValue: Decimal {
        transactions.isEmpty ? 0 : totalRevenue / Decimal(transactions.count)
    }
    
    private func calculateSuccessRate() -> String {
        let completed = Double(transactions.filter { $0.status == .completed }.count)
        let total = Double(transactions.count)
        let rate = total > 0 ? (completed / total) * 100 : 0
        return String(format: "%.1f", rate)
    }
}

#Preview {
    AdminDashboardView()
        .modelContainer(for: [Transaction.self, User.self], inMemory: true)
} 