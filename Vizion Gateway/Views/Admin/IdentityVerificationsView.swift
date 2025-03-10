import SwiftUI
import SwiftData

struct IdentityVerificationsView: View {
    @State private var verifications: [BasicIdentityVerification] = []
    @State private var searchText = ""
    @State private var isAutoRefreshing = true
    @State private var lastRefreshed = Date()
    @State private var selectedStatus: BasicVerificationStatus?
    @State private var showingFilters = false
    @State private var dateRange: ClosedRange<Date>?
    
    var filteredVerifications: [BasicIdentityVerification] {
        let initialVerifications = verifications.prefix(1000)
        
        return initialVerifications.filter { verification in
            // Check search text
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = verification.customerName.localizedCaseInsensitiveContains(searchText) ||
                              verification.customerEmail.localizedCaseInsensitiveContains(searchText) ||
                              verification.merchantId.localizedCaseInsensitiveContains(searchText)
            }
            
            // Check status
            let matchesStatus: Bool
            if let status = selectedStatus {
                matchesStatus = verification.status == status
            } else {
                matchesStatus = true
            }
            
            // Check date range
            let matchesDate: Bool
            if let range = dateRange {
                matchesDate = range.contains(verification.submittedAt)
            } else {
                matchesDate = true
            }
            
            return matchesSearch && matchesStatus && matchesDate
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Status Bar
            StatusBar(
                isAutoRefreshing: isAutoRefreshing,
                lastRefreshed: lastRefreshed
            )
            
            if verifications.isEmpty {
                VerificationEmptyStateView()
            } else {
                List {
                    ForEach(filteredVerifications) { verification in
                        VerificationItemRow(verification: verification)
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "Search verifications...")
        .navigationTitle("Identity Verifications")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button {
                        isAutoRefreshing.toggle()
                    } label: {
                        Label(isAutoRefreshing ? "Pause" : "Resume", 
                              systemImage: isAutoRefreshing ? "pause.fill" : "play.fill")
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
            VerificationFilterView(
                selectedStatus: $selectedStatus,
                dateRange: $dateRange
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task {
            // Auto-refresh every 5 seconds when enabled
            while isAutoRefreshing {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                // In a real app, fetch new verifications here
                lastRefreshed = Date()
            }
        }
    }
}

struct StatusBar: View {
    let isAutoRefreshing: Bool
    let lastRefreshed: Date
    
    var body: some View {
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
    }
}

struct VerificationEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Verification Requests")
                .font(.headline)
            Text("When users submit verification requests, they will appear here.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct VerificationItemRow: View {
    let verification: BasicIdentityVerification
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verification.submittedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verification.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(verification.status.color.opacity(0.2))
                    .foregroundStyle(verification.status.color)
                    .clipShape(Capsule())
            }
            
            Text(verification.customerName)
                .font(.headline)
            Text(verification.customerEmail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if !verification.notes.isEmpty {
                Text(verification.notes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct VerificationFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedStatus: BasicVerificationStatus?
    @Binding var dateRange: ClosedRange<Date>?
    @State private var startDate = Date()
    @State private var endDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Status") {
                    Picker("Status", selection: $selectedStatus) {
                        Text("Any").tag(nil as BasicVerificationStatus?)
                        ForEach(BasicVerificationStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status as BasicVerificationStatus?)
                        }
                    }
                }
                
                Section("Date Range") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End Date", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section {
                    Button("Apply Filters") {
                        dateRange = startDate...endDate
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button("Clear Filters") {
                        selectedStatus = nil
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

// Models
struct IdentityVerification: Identifiable {
    let id: String
    let customerName: String
    let customerEmail: String
    let merchantId: String
    let submittedAt: Date
    let status: BasicVerificationStatus
    let notes: String
    let documentType: BasicDocumentType
    
    init(
        id: String = UUID().uuidString,
        customerName: String,
        customerEmail: String,
        merchantId: String,
        submittedAt: Date = Date(),
        status: BasicVerificationStatus = .pending,
        notes: String = "",
        documentType: BasicDocumentType
    ) {
        self.id = id
        self.customerName = customerName
        self.customerEmail = customerEmail
        self.merchantId = merchantId
        self.submittedAt = submittedAt
        self.status = status
        self.notes = notes
        self.documentType = documentType
    }
}

struct IdentityVerificationsView_Previews: PreviewProvider {
    static var previews: some View {
        IdentityVerificationsView()
    }
} 