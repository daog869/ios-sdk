import SwiftUI
import SwiftData

struct FraudDetectionView: View {
    @Query private var transactions: [Transaction]
    @State private var searchText = ""
    @State private var selectedRiskLevel: RiskLevel?
    @State private var showingFilters = false
    
    private var filteredTransactions: [Transaction] {
        // First filter by search text
        let searchFiltered = transactions.filter { transaction in
            if searchText.isEmpty {
                return true
            }
            return transaction.merchantName.localizedCaseInsensitiveContains(searchText) ||
                   transaction.id.uuidString.localizedCaseInsensitiveContains(searchText)
        }
        
        // Then filter by risk level if selected
        if let riskLevel = selectedRiskLevel {
            return searchFiltered.filter { transaction in
                calculateRiskLevel(for: transaction) == riskLevel
            }
        }
        
        return searchFiltered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Fraud Overview Cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        MetricCard(
                            title: "High Risk",
                            value: "\(countTransactions(with: .high))",
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        )
                        
                        MetricCard(
                            title: "Medium Risk",
                            value: "\(countTransactions(with: .medium))",
                            icon: "exclamationmark.circle.fill",
                            color: .orange
                        )
                        
                        MetricCard(
                            title: "Low Risk",
                            value: "\(countTransactions(with: .low))",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    }
                    .padding()
                }
                
                // Transaction List
                List {
                    ForEach(filteredTransactions) { transaction in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(transaction.merchantName)
                                    .font(.headline)
                                Spacer()
                                RiskBadge(level: calculateRiskLevel(for: transaction))
                            }
                            
                            HStack {
                                Text(transaction.id.uuidString.prefix(8))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(transaction.amount.formatted(.currency(code: "XCD")))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
            .ignoresSafeArea(edges: .horizontal)
            .searchable(text: $searchText, prompt: "Search transactions...")
            .navigationTitle("Fraud Detection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FraudFilterView(selectedRiskLevel: $selectedRiskLevel)
                    .presentationDragIndicator(.visible)
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func countTransactions(with riskLevel: RiskLevel) -> Int {
        transactions.filter { calculateRiskLevel(for: $0) == riskLevel }.count
    }
    
    private func calculateRiskLevel(for transaction: Transaction) -> RiskLevel {
        // In a real app, implement sophisticated risk scoring
        // This is just a simple example
        if transaction.amount > 10000 {
            return .high
        } else if transaction.amount > 5000 {
            return .medium
        } else {
            return .low
        }
    }
}

enum RiskLevel: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

struct RiskBadge: View {
    let level: RiskLevel
    
    var body: some View {
        Text(level.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(level.color.opacity(0.2))
            .foregroundStyle(level.color)
            .clipShape(Capsule())
    }
}

struct FraudFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRiskLevel: RiskLevel?
    @State private var selectedDateRange = "Last 7 Days"
    
    let dateRanges = ["Last 7 Days", "Last 30 Days", "Last 90 Days", "Custom"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Risk Level") {
                    Picker("Risk Level", selection: .init(
                        get: { selectedRiskLevel ?? .high },
                        set: { selectedRiskLevel = $0 }
                    )) {
                        Text("All").tag(nil as RiskLevel?)
                        ForEach(RiskLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as RiskLevel?)
                        }
                    }
                }
                
                Section("Date Range") {
                    Picker("Date Range", selection: $selectedDateRange) {
                        ForEach(dateRanges, id: \.self) { range in
                            Text(range).tag(range)
                        }
                    }
                }
            }
            .navigationTitle("Filter Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        selectedRiskLevel = nil
                        selectedDateRange = "Last 7 Days"
                    }
                }
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
        FraudDetectionView()
    }
    .modelContainer(for: [Transaction.self], inMemory: true)
} 