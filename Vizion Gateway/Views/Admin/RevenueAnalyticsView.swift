import SwiftUI
import SwiftData
import Charts

struct RevenueAnalyticsView: View {
    @Query private var transactions: [Transaction]
    @State private var timeRange: TimeRange = .month
    @State private var selectedDataPoint: DataPoint?
    
    var filteredTransactions: [Transaction] {
        transactions.filter { transaction in
            switch timeRange {
            case .today:
                return Calendar.current.isDateInToday(transaction.timestamp)
            case .week:
                return Calendar.current.isDate(transaction.timestamp, equalTo: Date(), toGranularity: .weekOfYear)
            case .month:
                return Calendar.current.isDate(transaction.timestamp, equalTo: Date(), toGranularity: .month)
            case .year:
                return Calendar.current.isDate(transaction.timestamp, equalTo: Date(), toGranularity: .year)
            }
        }
    }
    
    var body: some View {
        List {
            Section {
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section {
                RevenueMetricsView(transactions: filteredTransactions)
            }
            
            Section("Revenue Trends") {
                RevenueTrendChart(transactions: filteredTransactions)
                    .frame(height: 300)
            }
            
            Section("Payment Methods") {
                PaymentMethodDistributionChart(transactions: filteredTransactions)
                    .frame(height: 300)
            }
            
            Section("Transaction Volume") {
                TransactionVolumeChart(transactions: filteredTransactions)
                    .frame(height: 300)
            }
            
            Section("Top Merchants") {
                TopMerchantsView(transactions: filteredTransactions)
            }
        }
        .navigationTitle("Revenue Analytics")
    }
}

struct RevenueMetricsView: View {
    let transactions: [Transaction]
    
    var totalRevenue: Decimal {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    var averageTransactionValue: Decimal {
        transactions.isEmpty ? 0 : totalRevenue / Decimal(transactions.count)
    }
    
    var successRate: Double {
        let completed = Double(transactions.filter { $0.status == .completed }.count)
        let total = Double(transactions.count)
        return total > 0 ? (completed / total) * 100 : 0
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                MetricCard(
                    title: "Total Revenue",
                    value: totalRevenue.formatted(.currency(code: "XCD")),
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                Divider()
                
                MetricCard(
                    title: "Avg. Transaction",
                    value: averageTransactionValue.formatted(.currency(code: "XCD")),
                    icon: "chart.bar.fill",
                    color: .blue
                )
            }
            
            HStack {
                MetricCard(
                    title: "Success Rate",
                    value: "\(successRate.formatted(.number.precision(.fractionLength(1))))%",
                    icon: "checkmark.circle.fill",
                    color: successRate >= 95 ? .green : .orange
                )
                
                Divider()
                
                MetricCard(
                    title: "Transactions",
                    value: "\(transactions.count)",
                    icon: "arrow.left.arrow.right",
                    color: .purple
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PaymentMethodDistributionChart: View {
    let transactions: [Transaction]
    
    var groupedData: [(PaymentMethod, Decimal)] {
        let grouped = Dictionary(grouping: transactions) { $0.paymentMethod }
        let methodAmounts = grouped.map { method, transactions in
            (method, transactions.reduce(0) { $0 + $1.amount })
        }
        return methodAmounts.sorted { $0.1 > $1.1 }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Revenue by Payment Method")
                .font(.headline)
            
            let chartContent = Chart {
                ForEach(groupedData, id: \.0) { method, amount in
                    SectorMark(
                        angle: .value("Amount", amount),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Method", method.rawValue))
                }
            }
            
            chartContent
            
            VStack(spacing: 8) {
                ForEach(groupedData, id: \.0) { method, amount in
                    HStack {
                        Text(method.rawValue)
                        Spacer()
                        Text(amount.formatted(.currency(code: "XCD")))
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                }
            }
            .padding(.top)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TransactionVolumeChart: View {
    let transactions: [Transaction]
    
    var hourlyData: [(hour: Int, count: Int, amount: Decimal)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.component(.hour, from: transaction.timestamp)
        }
        return (0...23).map { hour in
            let hourTransactions = grouped[hour] ?? []
            return (
                hour: hour,
                count: hourTransactions.count,
                amount: hourTransactions.reduce(0) { $0 + $1.amount }
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Hourly Transaction Volume")
                .font(.headline)
            
            let chartContent = Chart {
                // Transaction count bars
                ForEach(hourlyData, id: \.hour) { data in
                    BarMark(
                        x: .value("Hour", data.hour),
                        y: .value("Count", data.count)
                    )
                    .foregroundStyle(.blue.opacity(0.8))
                }
                
                // Amount line
                ForEach(hourlyData, id: \.hour) { data in
                    let normalizedAmount = Double(truncating: data.amount as NSNumber) / 100
                    LineMark(
                        x: .value("Hour", data.hour),
                        y: .value("Amount", normalizedAmount)
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)
                }
            }
            
            chartContent
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartForegroundStyleScale([
                    "Transactions": Color.blue,
                    "Amount": Color.green
                ])
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TopMerchantsView: View {
    let transactions: [Transaction]
    
    var merchantData: [(merchant: String, amount: Decimal)] {
        let grouped = Dictionary(grouping: transactions) { $0.merchantName }
        return grouped.map { (merchant: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
            .prefix(5)
            .map { ($0.merchant, $0.amount) }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(merchantData, id: \.merchant) { data in
                HStack {
                    Text(data.merchant)
                        .font(.subheadline)
                    Spacer()
                    Text(data.amount.formatted(.currency(code: "XCD")))
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Decimal
    let label: String
}

#Preview {
    NavigationView {
        RevenueAnalyticsView()
    }
    .modelContainer(for: Transaction.self, inMemory: true)
} 