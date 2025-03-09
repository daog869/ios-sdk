import SwiftUI
import SwiftData

struct DisputeManagementView: View {
    @State private var searchText = ""
    @State private var selectedDispute: Dispute?
    @State private var selectedStatus = "Open"
    @State private var showingFilters = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Dispute Overview Cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        MetricCard(
                            title: "Open Disputes",
                            value: "5",
                            icon: "exclamationmark.circle.fill",
                            color: .red
                        )
                        
                        MetricCard(
                            title: "Pending Response",
                            value: "3",
                            icon: "clock.fill",
                            color: .orange
                        )
                        
                        MetricCard(
                            title: "Win Rate",
                            value: "85%",
                            icon: "chart.line.uptrend.xyaxis.fill",
                            color: .green
                        )
                    }
                    .padding()
                }
                
                // Status Tabs
                Picker("Status", selection: $selectedStatus) {
                    Text("Open").tag("Open")
                    Text("Pending").tag("Pending")
                    Text("Resolved").tag("Resolved")
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Dispute List
                List {
                    ForEach(0..<10) { _ in
                        DisputeRow()
                            .onTapGesture {
                                selectedDispute = Dispute()
                            }
                    }
                }
                .listStyle(.plain)
            }
            .ignoresSafeArea(edges: .horizontal)
            .searchable(text: $searchText, prompt: "Search disputes...")
            .navigationTitle("Disputes")
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
                DisputeFilterView()
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedDispute) { dispute in
                DisputeDetailView(dispute: dispute)
                    .presentationDragIndicator(.visible)
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct DisputeRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transaction ID: TX123456")
                    .font(.headline)
                Spacer()
                Text("Open")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
            
            HStack {
                Label("Amount: $123.45", systemImage: "dollarsign.circle")
                Spacer()
                Label("Merchant: Sample Store", systemImage: "building.2")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            HStack {
                Label("Reason: Unauthorized Transaction", systemImage: "exclamationmark.bubble")
                Spacer()
                Label("Due: 2d 4h", systemImage: "clock")
                    .foregroundStyle(.red)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct DisputeDetailView: View {
    let dispute: Dispute
    @Environment(\.dismiss) private var dismiss
    @State private var response = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Dispute Information") {
                    LabeledContent("Transaction ID", value: "TX123456")
                    LabeledContent("Amount", value: "$123.45")
                    LabeledContent("Status", value: "Open")
                    LabeledContent("Reason", value: "Unauthorized Transaction")
                    LabeledContent("Filed Date", value: "Jan 15, 2025")
                    LabeledContent("Due Date", value: "Jan 17, 2025")
                }
                
                Section("Transaction Details") {
                    LabeledContent("Merchant", value: "Sample Store")
                    LabeledContent("Customer", value: "John Doe")
                    LabeledContent("Payment Method", value: "Visa ***1234")
                    LabeledContent("Transaction Date", value: "Jan 14, 2025")
                }
                
                Section("Evidence") {
                    NavigationLink("Transaction Receipt") {
                        Text("Receipt")
                    }
                    
                    NavigationLink("Customer Communication") {
                        Text("Communication")
                    }
                    
                    NavigationLink("Delivery Confirmation") {
                        Text("Delivery")
                    }
                }
                
                Section("Response") {
                    TextEditor(text: $response)
                        .frame(height: 100)
                }
                
                Section {
                    Button("Submit Response") {
                        // Submit dispute response
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button("Accept Dispute") {
                        // Accept the dispute
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Dispute Details")
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

struct Dispute: Identifiable {
    let id = UUID()
    var transactionId: String = ""
    var amount: Decimal = 0
    var status: DisputeStatus = .open
    var reason: String = ""
    var filedDate: Date = Date()
    var dueDate: Date = Date()
    var merchantId: String = ""
    var customerId: String = ""
    var evidence: [Evidence] = []
    var response: String = ""
}

enum DisputeStatus: String {
    case open = "Open"
    case pending = "Pending"
    case resolved = "Resolved"
    case accepted = "Accepted"
    case rejected = "Rejected"
    
    var color: Color {
        switch self {
        case .open: return .orange
        case .pending: return .yellow
        case .resolved: return .blue
        case .accepted: return .red
        case .rejected: return .green
        }
    }
}

struct Evidence: Identifiable {
    let id = UUID()
    var type: EvidenceType
    var url: URL
    var uploadDate: Date
}

enum EvidenceType: String {
    case receipt = "Transaction Receipt"
    case communication = "Customer Communication"
    case delivery = "Delivery Confirmation"
    case other = "Other Evidence"
}

struct DisputeFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDateRange = "Last 7 Days"
    @State private var selectedReason = "All"
    @State private var selectedAmount = "All"
    
    let dateRanges = ["Last 7 Days", "Last 30 Days", "Last 90 Days", "Custom"]
    let reasons = ["All", "Unauthorized", "Product Not Received", "Product Defective", "Wrong Amount", "Other"]
    let amounts = ["All", "Under $100", "$100-$500", "$500-$1000", "Over $1000"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Date Range") {
                    Picker("Date Range", selection: $selectedDateRange) {
                        ForEach(dateRanges, id: \.self) { range in
                            Text(range).tag(range)
                        }
                    }
                }
                
                Section("Reason") {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(reasons, id: \.self) { reason in
                            Text(reason).tag(reason)
                        }
                    }
                }
                
                Section("Amount") {
                    Picker("Amount", selection: $selectedAmount) {
                        ForEach(amounts, id: \.self) { amount in
                            Text(amount).tag(amount)
                        }
                    }
                }
            }
            .navigationTitle("Filter Disputes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        selectedDateRange = "Last 7 Days"
                        selectedReason = "All"
                        selectedAmount = "All"
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