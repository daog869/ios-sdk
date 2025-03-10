import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [WalletTransaction]
    
    // User data
    private let userId: String
    private let walletType: WalletType
    
    // Filtering state
    @State private var searchText = ""
    @State private var filterType: WalletTransactionType?
    @State private var filterStatus: WalletTransactionStatus?
    @State private var filterCurrency: Currency?
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var showingFilters = false
    @State private var sortOrder: SortOrder = .reverse
    
    // Detail view
    @State private var selectedTransaction: WalletTransaction?
    @State private var showingTransactionDetail = false
    
    init(userId: String, walletType: WalletType) {
        self.userId = userId
        self.walletType = walletType
        
        // Use a basic query without sorting - we'll handle sort in memory
        _transactions = Query()
    }
    
    var body: some View {
        List {
            // Filter section
            Section {
                HStack {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .foregroundColor(.secondary)
                    
                    Button("Filter Transactions") {
                        showingFilters = true
                    }
                    
                    Spacer()
                    
                    if hasActiveFilters {
                        Button("Clear") {
                            clearFilters()
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                if hasActiveFilters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            if let type = filterType {
                                FilterPill(text: typeLabel(type), color: .blue) {
                                    filterType = nil
                                }
                            }
                            
                            if let status = filterStatus {
                                FilterPill(text: statusLabel(status), color: .green) {
                                    filterStatus = nil
                                }
                            }
                            
                            if let currency = filterCurrency {
                                FilterPill(text: currency.rawValue, color: .purple) {
                                    filterCurrency = nil
                                }
                            }
                            
                            if startDate != nil || endDate != nil {
                                FilterPill(text: "Date Range", color: .orange) {
                                    startDate = nil
                                    endDate = nil
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Transactions
            if filteredTransactions.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No transactions found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            if hasActiveFilters {
                                Text("Try clearing your filters")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 40)
                        Spacer()
                    }
                }
            } else {
                ForEach(filteredTransactions) { transaction in
                    WalletTransactionRow(transaction: transaction)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTransaction = transaction
                            showingTransactionDetail = true
                        }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search transactions")
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        sortOrder = .forward
                    } label: {
                        Label("Oldest First", systemImage: "arrow.up")
                    }
                    
                    Button {
                        sortOrder = .reverse
                    } label: {
                        Label("Newest First", systemImage: "arrow.down")
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            WalletTransactionFilterView(
                filterType: $filterType,
                filterStatus: $filterStatus,
                filterCurrency: $filterCurrency,
                startDate: $startDate,
                endDate: $endDate
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingTransactionDetail) {
            if let transaction = selectedTransaction {
                WalletTransactionDetailView(transaction: transaction)
            }
        }
    }
    
    var filteredTransactions: [WalletTransaction] {
        // First filter by user and wallet type
        let userTransactions = transactions.filter { transaction in
            (transaction.sourceType == (walletType == .user ? .user : .merchant) && 
             transaction.sourceId == userId) ||
            (transaction.destinationType == (walletType == .user ? .user : .merchant) && 
             transaction.destinationId == userId)
        }
        
        // Then apply all other filters
        let filtered = userTransactions.filter { transaction in
            // Filter by search text if provided
            let matchesSearch = searchText.isEmpty ||
                (transaction.transactionDescription?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                transaction.id.localizedCaseInsensitiveContains(searchText) ||
                (transaction.reference?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            // Filter by type if selected
            let matchesType = filterType == nil || transaction.type == filterType
            
            // Filter by status if selected
            let matchesStatus = filterStatus == nil || transaction.status == filterStatus
            
            // Filter by currency if selected
            let matchesCurrency = filterCurrency == nil || transaction.currency == filterCurrency
            
            // Filter by date range if provided
            let matchesStartDate = startDate == nil || transaction.createdAt >= startDate!
            let matchesEndDate = endDate == nil || transaction.createdAt <= endDate!
            
            return matchesSearch && matchesType && matchesStatus && matchesCurrency &&
                   matchesStartDate && matchesEndDate
        }
        
        // Finally, sort according to the current sort order
        return filtered.sorted { 
            if sortOrder == .reverse {
                return $0.createdAt > $1.createdAt
            } else {
                return $0.createdAt < $1.createdAt
            }
        }
    }
    
    private var hasActiveFilters: Bool {
        filterType != nil || filterStatus != nil || filterCurrency != nil || 
        startDate != nil || endDate != nil
    }
    
    private func clearFilters() {
        filterType = nil
        filterStatus = nil
        filterCurrency = nil
        startDate = nil
        endDate = nil
    }
    
    private func typeLabel(_ type: WalletTransactionType) -> String {
        switch type {
        case .deposit: return "Deposit"
        case .withdrawal: return "Withdrawal"
        case .payment: return "Payment"
        case .refund: return "Refund"
        case .chargeback: return "Chargeback"
        case .fee: return "Fee"
        case .transfer: return "Transfer"
        case .settlement: return "Settlement"
        case .reserveRelease: return "Reserve Release"
        }
    }
    
    private func statusLabel(_ status: WalletTransactionStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .reversed: return "Reversed"
        case .disputed: return "Disputed"
        }
    }
}

struct WalletTransactionRow: View {
    let transaction: WalletTransaction
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: iconName(for: transaction.type))
                .font(.title3)
                .foregroundColor(color(for: transaction.type))
                .frame(width: 40, height: 40)
                .background(color(for: transaction.type).opacity(0.1))
                .cornerRadius(20)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(title(for: transaction))
                    .font(.headline)
                
                HStack {
                    Text(transaction.createdAt.formatted(date: .abbreviated, time: .shortened))
                    
                    if transaction.status != .completed {
                        Text("•")
                        Text(transaction.status.rawValue.capitalized)
                            .foregroundColor(statusColor(for: transaction.status))
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount(for: transaction))
                    .font(.headline)
                    .foregroundColor(amountColor(for: transaction))
                
                Text(transaction.currency.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func iconName(for type: WalletTransactionType) -> String {
        switch type {
        case .deposit: return "arrow.down.circle"
        case .withdrawal: return "arrow.up.circle"
        case .payment: return "creditcard"
        case .refund: return "arrow.counterclockwise.circle"
        case .chargeback: return "exclamationmark.triangle"
        case .fee: return "percent"
        case .transfer: return "arrow.left.arrow.right"
        case .settlement: return "building.columns"
        case .reserveRelease: return "lock.open"
        }
    }
    
    private func color(for type: WalletTransactionType) -> Color {
        switch type {
        case .deposit, .refund, .reserveRelease: return .green
        case .withdrawal, .payment, .fee, .settlement: return .orange
        case .chargeback: return .red
        case .transfer: return .blue
        }
    }
    
    private func title(for transaction: WalletTransaction) -> String {
        switch transaction.type {
        case .deposit: return "Deposit"
        case .withdrawal: return "Withdrawal"
        case .payment: return transaction.transactionDescription ?? "Payment"
        case .refund: return "Refund"
        case .chargeback: return "Chargeback"
        case .fee: return "Fee"
        case .transfer: return "Transfer"
        case .settlement: return "Settlement"
        case .reserveRelease: return "Reserve Release"
        }
    }
    
    private func statusColor(for status: WalletTransactionStatus) -> Color {
        switch status {
        case .pending, .processing: return .orange
        case .completed: return .green
        case .failed, .reversed, .disputed: return .red
        }
    }
    
    private func formattedAmount(for transaction: WalletTransaction) -> String {
        let prefix: String
        
        switch transaction.type {
        case .deposit, .refund, .reserveRelease:
            prefix = "+"
        case .withdrawal, .payment, .fee, .chargeback, .settlement:
            prefix = "-"
        case .transfer:
            // For transfers, check if the user is the source or destination
            if transaction.destinationType == .user {
                prefix = "+"
            } else {
                prefix = "-"
            }
        }
        
        return "\(prefix)\(transaction.amount.formatted(.currency(code: transaction.currency.rawValue)))"
    }
    
    private func amountColor(for transaction: WalletTransaction) -> Color {
        switch transaction.type {
        case .deposit, .refund, .reserveRelease:
            return .green
        case .withdrawal, .payment, .fee, .chargeback, .settlement:
            return .red
        case .transfer:
            // For transfers, check if the user is the source or destination
            if transaction.destinationType == .user {
                return .green
            } else {
                return .red
            }
        }
    }
}

struct FilterPill: View {
    let text: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .padding(.leading, 8)
                .padding(.vertical, 4)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .padding(.horizontal, 4)
            }
        }
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .cornerRadius(12)
    }
}

struct WalletTransactionFilterView: View {
    @Binding var filterType: WalletTransactionType?
    @Binding var filterStatus: WalletTransactionStatus?
    @Binding var filterCurrency: Currency?
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDateRange: DateRangeSelection = .all
    
    var body: some View {
        NavigationView {
            Form {
                // Transaction Type
                Section("Transaction Type") {
                    Picker("Type", selection: $filterType) {
                        Text("All Types").tag(nil as WalletTransactionType?)
                        ForEach(WalletTransactionType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type as WalletTransactionType?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Transaction Status
                Section("Transaction Status") {
                    Picker("Status", selection: $filterStatus) {
                        Text("All Statuses").tag(nil as WalletTransactionStatus?)
                        ForEach(WalletTransactionStatus.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(status as WalletTransactionStatus?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Currency
                Section("Currency") {
                    Picker("Currency", selection: $filterCurrency) {
                        Text("All Currencies").tag(nil as Currency?)
                        ForEach(Currency.allCases, id: \.self) { currency in
                            Text(currency.rawValue).tag(currency as Currency?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Date Range
                Section("Date Range") {
                    Picker("Time Period", selection: $selectedDateRange) {
                        ForEach(DateRangeSelection.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedDateRange) { newValue in
                        updateDateRange(for: newValue)
                    }
                    
                    if selectedDateRange == .custom {
                        DatePicker("Start Date", selection: Binding(
                            get: { startDate ?? Date() },
                            set: { startDate = $0 }
                        ), displayedComponents: .date)
                        
                        DatePicker("End Date", selection: Binding(
                            get: { endDate ?? Date() },
                            set: { endDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
                
                // Actions
                Section {
                    Button("Apply Filters") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                    
                    Button("Reset All Filters") {
                        filterType = nil
                        filterStatus = nil
                        filterCurrency = nil
                        startDate = nil
                        endDate = nil
                        selectedDateRange = .all
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filter Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Set initial date range selection based on current filters
                if startDate == nil && endDate == nil {
                    selectedDateRange = .all
                } else if let start = startDate, let end = endDate {
                    let calendar = Calendar.current
                    let now = Date()
                    
                    if calendar.isDate(start, inSameDayAs: calendar.date(byAdding: .day, value: -7, to: now)!) &&
                       calendar.isDate(end, inSameDayAs: now) {
                        selectedDateRange = .lastWeek
                    } else if calendar.isDate(start, inSameDayAs: calendar.date(byAdding: .month, value: -1, to: now)!) &&
                              calendar.isDate(end, inSameDayAs: now) {
                        selectedDateRange = .lastMonth
                    } else if calendar.isDate(start, inSameDayAs: calendar.date(byAdding: .month, value: -3, to: now)!) &&
                              calendar.isDate(end, inSameDayAs: now) {
                        selectedDateRange = .last3Months
                    } else {
                        selectedDateRange = .custom
                    }
                }
            }
        }
    }
    
    private func updateDateRange(for selection: DateRangeSelection) {
        let calendar = Calendar.current
        let now = Date()
        
        switch selection {
        case .all:
            startDate = nil
            endDate = nil
        case .today:
            startDate = calendar.startOfDay(for: now)
            endDate = now
        case .lastWeek:
            startDate = calendar.date(byAdding: .day, value: -7, to: now)
            endDate = now
        case .lastMonth:
            startDate = calendar.date(byAdding: .month, value: -1, to: now)
            endDate = now
        case .last3Months:
            startDate = calendar.date(byAdding: .month, value: -3, to: now)
            endDate = now
        case .custom:
            // Keep existing dates or set defaults
            if startDate == nil {
                startDate = calendar.date(byAdding: .month, value: -1, to: now)
            }
            if endDate == nil {
                endDate = now
            }
        }
    }
}

struct WalletTransactionDetailView: View {
    let transaction: WalletTransaction
    
    var body: some View {
        NavigationView {
            List {
                // Transaction overview
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: iconName(for: transaction.type))
                                .font(.system(size: 48))
                                .foregroundColor(color(for: transaction.type))
                                .padding()
                                .background(color(for: transaction.type).opacity(0.1))
                                .clipShape(Circle())
                            
                            Text(title(for: transaction))
                                .font(.headline)
                            
                            if let description = transaction.transactionDescription {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(formattedAmount(for: transaction))
                                .font(.title)
                                .foregroundColor(amountColor(for: transaction))
                                .padding(.top, 4)
                            
                            Text(transaction.currency.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            // Status badge
                            Text(transaction.status.rawValue.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(statusColor(for: transaction.status).opacity(0.1))
                                .foregroundColor(statusColor(for: transaction.status))
                                .cornerRadius(12)
                                .padding(.top, 4)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                
                // Transaction details
                Section("Transaction Details") {
                    LabeledContent("ID", value: transaction.id)
                    
                    LabeledContent("Date", value: transaction.createdAt.formatted(date: .long, time: .shortened))
                    
                    if let completedAt = transaction.completedAt {
                        LabeledContent("Completed", value: completedAt.formatted(date: .long, time: .shortened))
                    }
                    
                    if let reference = transaction.reference {
                        LabeledContent("Reference", value: reference)
                    }
                    
                    if let failedReason = transaction.failedReason {
                        LabeledContent("Failure Reason", value: failedReason)
                    }
                }
                
                // Fee breakdown (if applicable)
                if transaction.fee > 0 || transaction.platformFee > 0 || transaction.reserveAmount > 0 {
                    Section("Fee Breakdown") {
                        if transaction.fee > 0 {
                            LabeledContent("Processing Fee", value: transaction.fee.formatted(.currency(code: transaction.currency.rawValue)))
                        }
                        
                        if transaction.platformFee > 0 {
                            LabeledContent("Platform Fee", value: transaction.platformFee.formatted(.currency(code: transaction.currency.rawValue)))
                        }
                        
                        if transaction.reserveAmount > 0 {
                            LabeledContent("Reserve Amount", value: transaction.reserveAmount.formatted(.currency(code: transaction.currency.rawValue)))
                        }
                        
                        LabeledContent("Net Amount", value: transaction.netAmount.formatted(.currency(code: transaction.currency.rawValue)))
                            .fontWeight(.bold)
                    }
                }
                
                // Source and destination
                Section("Participants") {
                    LabeledContent("From", value: "\(transaction.sourceType.rawValue.capitalized) (\(formatId(transaction.sourceId)))")
                    
                    LabeledContent("To", value: "\(transaction.destinationType.rawValue.capitalized) (\(formatId(transaction.destinationId)))")
                }
                
                // Currency conversion info (if applicable)
                if transaction.exchangeRate != nil && transaction.originalCurrency != nil && transaction.originalAmount != nil {
                    Section("Currency Conversion") {
                        LabeledContent("Original Amount", value: transaction.originalAmount!.formatted(.currency(code: transaction.originalCurrency!.rawValue)))
                        
                        LabeledContent("Exchange Rate", value: String(format: "1 %@ = %.4f %@", transaction.originalCurrency!.rawValue, transaction.exchangeRate!, transaction.currency.rawValue))
                    }
                }
                
                // External reference
                if transaction.externalId != nil || transaction.gatewayTransactionId != nil {
                    Section("External References") {
                        if let externalId = transaction.externalId {
                            LabeledContent("External ID", value: externalId)
                        }
                        
                        if let gatewayId = transaction.gatewayTransactionId {
                            LabeledContent("Gateway ID", value: gatewayId)
                        }
                    }
                }
                
                // Metadata
                if let metadata = transaction.metadata, !metadata.isEmpty {
                    Section("Metadata") {
                        ForEach(metadata.keys.sorted(), id: \.self) { key in
                            if let value = metadata[key] {
                                LabeledContent(key, value: value)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func formatId(_ id: String) -> String {
        if id.count > 10 {
            return String(id.prefix(4)) + "..." + String(id.suffix(4))
        }
        return id
    }
    
    private func iconName(for type: WalletTransactionType) -> String {
        switch type {
        case .deposit: return "arrow.down.circle"
        case .withdrawal: return "arrow.up.circle"
        case .payment: return "creditcard"
        case .refund: return "arrow.counterclockwise.circle"
        case .chargeback: return "exclamationmark.triangle"
        case .fee: return "percent"
        case .transfer: return "arrow.left.arrow.right"
        case .settlement: return "building.columns"
        case .reserveRelease: return "lock.open"
        }
    }
    
    private func color(for type: WalletTransactionType) -> Color {
        switch type {
        case .deposit, .refund, .reserveRelease: return .green
        case .withdrawal, .payment, .fee, .settlement: return .orange
        case .chargeback: return .red
        case .transfer: return .blue
        }
    }
    
    private func title(for transaction: WalletTransaction) -> String {
        switch transaction.type {
        case .deposit: return "Deposit"
        case .withdrawal: return "Withdrawal"
        case .payment: return transaction.transactionDescription ?? "Payment"
        case .refund: return "Refund"
        case .chargeback: return "Chargeback"
        case .fee: return "Fee"
        case .transfer: return "Transfer"
        case .settlement: return "Settlement"
        case .reserveRelease: return "Reserve Release"
        }
    }
    
    private func statusColor(for status: WalletTransactionStatus) -> Color {
        switch status {
        case .pending, .processing: return .orange
        case .completed: return .green
        case .failed, .reversed, .disputed: return .red
        }
    }
    
    private func formattedAmount(for transaction: WalletTransaction) -> String {
        let prefix: String
        
        switch transaction.type {
        case .deposit, .refund, .reserveRelease:
            prefix = "+"
        case .withdrawal, .payment, .fee, .chargeback, .settlement:
            prefix = "-"
        case .transfer:
            // For transfers, check if the user is the source or destination
            if transaction.destinationType == .user {
                prefix = "+"
            } else {
                prefix = "-"
            }
        }
        
        return "\(prefix)\(transaction.amount.formatted(.currency(code: transaction.currency.rawValue)))"
    }
    
    private func amountColor(for transaction: WalletTransaction) -> Color {
        switch transaction.type {
        case .deposit, .refund, .reserveRelease:
            return .green
        case .withdrawal, .payment, .fee, .chargeback, .settlement:
            return .red
        case .transfer:
            // For transfers, check if the user is the source or destination
            if transaction.destinationType == .user {
                return .green
            } else {
                return .red
            }
        }
    }
}

// MARK: - Supporting Types

enum DateRangeSelection: String, CaseIterable {
    case all
    case today
    case lastWeek
    case lastMonth
    case last3Months
    case custom
    
    var displayName: String {
        switch self {
        case .all: return "All Time"
        case .today: return "Today"
        case .lastWeek: return "Last 7 Days"
        case .lastMonth: return "Last 30 Days"
        case .last3Months: return "Last 3 Months"
        case .custom: return "Custom Range"
        }
    }
}

// For preview support
extension WalletTransactionType: CaseIterable {
    public static var allCases: [WalletTransactionType] {
        [.deposit, .withdrawal, .payment, .refund, .chargeback, .fee, .transfer, .settlement, .reserveRelease]
    }
}

extension WalletTransactionStatus: CaseIterable {
    public static var allCases: [WalletTransactionStatus] {
        [.pending, .processing, .completed, .failed, .reversed, .disputed]
    }
}

#Preview {
    NavigationStack {
        TransactionListView(userId: "preview_user", walletType: .user)
    }
} 