import SwiftUI
import SwiftData
import Charts

struct TransactionMonitoringView: View {
    @Query(sort: \Transaction.timestamp, order: .reverse) private var transactions: [Transaction]
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var selectedStatus: TransactionStatus?
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var dateRange: ClosedRange<Date>?
    @State private var showingTransactionDetail = false
    @State private var selectedTransaction: Transaction?
    @State private var isAutoRefreshing = true
    @State private var lastRefreshed = Date()
    
    var filteredTransactions: [Transaction] {
        transactions.prefix(1000).filter { transaction in
            var matches = true
            
            if !searchText.isEmpty {
                matches = matches && (
                    transaction.merchantName.localizedCaseInsensitiveContains(searchText) ||
                    transaction.customerID.localizedCaseInsensitiveContains(searchText) ||
                    transaction.reference?.localizedCaseInsensitiveContains(searchText) ?? false
                )
            }
            
            if let status = selectedStatus {
                matches = matches && transaction.status == status
            }
            
            if let method = selectedPaymentMethod {
                matches = matches && transaction.paymentMethod == method
            }
            
            if let range = dateRange {
                matches = matches && range.contains(transaction.timestamp)
            }
            
            return matches
        }
    }
    
    private var totalVolume: Decimal {
        filteredTransactions.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    private var averageAmount: Decimal {
        filteredTransactions.isEmpty ? 0 : totalVolume / Decimal(filteredTransactions.count)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status Bar
                HStack {
                    Circle()
                        .fill(isAutoRefreshing ? .green : .secondary)
                        .frame(width: 8, height: 8)
                    Text(isAutoRefreshing ? "Live" : "Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Last updated: \(lastRefreshed.formatted(.relative(presentation: .numeric)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        MetricCard(
                            title: "Total Volume",
                            value: totalVolume.formatted(.currency(code: "XCD")),
                            trend: "12% vs last week",
                            trendUp: true
                        )
                        
                        MetricCard(
                            title: "Success Rate",
                            value: "\(calculateSuccessRate())%",
                            trend: "2% vs last week",
                            trendUp: true
                        )
                        
                        MetricCard(
                            title: "Average Amount",
                            value: averageAmount.formatted(.currency(code: "XCD")),
                            trend: "5% vs last week",
                            trendUp: false
                        )
                    }
                    .padding()
                }
                
                Divider()
                
                // Transaction List
                List {
                    ForEach(filteredTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTransaction = transaction
                                showingTransactionDetail = true
                            }
                    }
                }
                .listStyle(.plain)
            }
            .ignoresSafeArea(edges: .horizontal)
            .searchable(text: $searchText, prompt: "Search transactions...")
            .navigationTitle("Transaction Monitor")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            isAutoRefreshing.toggle()
                        } label: {
                            Label(isAutoRefreshing ? "Pause" : "Resume", systemImage: isAutoRefreshing ? "pause.fill" : "play.fill")
                        }
                        
                        Button {
                            showingFilters = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterView(
                    selectedStatus: $selectedStatus,
                    selectedPaymentMethod: $selectedPaymentMethod,
                    dateRange: $dateRange
                )
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingTransactionDetail) {
                if let transaction = selectedTransaction {
                    TransactionDetailView(transaction: transaction)
                        .presentationDragIndicator(.visible)
                }
            }
            .task {
                // Auto-refresh every 5 seconds when enabled
                while isAutoRefreshing {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    lastRefreshed = Date()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func calculateSuccessRate() -> String {
        let completed = Double(filteredTransactions.filter { $0.status == .completed }.count)
        let total = Double(filteredTransactions.count)
        let rate = total > 0 ? (completed / total) * 100 : 0
        return String(format: "%.1f", rate)
    }
}

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedStatus: TransactionStatus?
    @Binding var selectedPaymentMethod: PaymentMethod?
    @Binding var dateRange: ClosedRange<Date>?
    @State private var startDate = Date()
    @State private var endDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Status") {
                    Picker("Status", selection: $selectedStatus) {
                        Text("Any").tag(nil as TransactionStatus?)
                        ForEach(TransactionStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status as TransactionStatus?)
                        }
                    }
                }
                
                Section("Payment Method") {
                    Picker("Method", selection: $selectedPaymentMethod) {
                        Text("Any").tag(nil as PaymentMethod?)
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method as PaymentMethod?)
                        }
                    }
                }
                
                Section("Date Range") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                    DatePicker("End Date", selection: $endDate, displayedComponents: [.date])
                }
                
                Section {
                    Button("Apply Filters") {
                        dateRange = startDate...endDate
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button("Clear Filters") {
                        selectedStatus = nil
                        selectedPaymentMethod = nil
                        dateRange = nil
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Transaction Details") {
                    LabeledContent("ID", value: transaction.id.uuidString)
                    LabeledContent("Amount", value: transaction.amount.formatted(.currency(code: "XCD")))
                    LabeledContent("Status", value: transaction.status.rawValue)
                    LabeledContent("Type", value: transaction.type.rawValue)
                    LabeledContent("Payment Method", value: transaction.paymentMethod.rawValue)
                    LabeledContent("Timestamp", value: transaction.timestamp, format: .dateTime)
                }
                
                Section("Merchant Details") {
                    LabeledContent("Name", value: transaction.merchantName)
                    LabeledContent("Customer ID", value: transaction.customerID)
                    if let reference = transaction.reference {
                        LabeledContent("Reference", value: reference)
                    }
                    if let description = transaction.transactionDescription {
                        LabeledContent("Description", value: description)
                    }
                }
                
                if transaction.status == .failed {
                    Section {
                        Button("Retry Transaction") {
                            // Implement retry logic
                        }
                        .foregroundStyle(.blue)
                    }
                }
                
                if transaction.status == .completed {
                    Section {
                        Button("Issue Refund") {
                            // Implement refund logic
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        TransactionMonitoringView()
    }
    .modelContainer(for: [Transaction.self], inMemory: true)
} 