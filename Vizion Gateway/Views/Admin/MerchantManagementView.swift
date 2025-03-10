import SwiftUI
import SwiftData

// Using MerchantStatus from Models.swift
extension MerchantStatus {
    var color: Color {
        switch self {
        case .active: return .green
        case .pending: return .orange
        case .suspended: return .red
        case .terminated: return .gray
        }
    }
}

struct MerchantManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var merchants: [Merchant]
    
    @State private var searchText = ""
    @State private var selectedMerchant: Merchant?
    @State private var showingAddMerchant = false
    @State private var selectedTab = "Active"
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Filter merchants based on search text and selected tab
    private var filteredMerchants: [Merchant] {
        merchants.filter { merchant in
            // Filter by status tab
            guard merchant.status.rawValue.lowercased() == selectedTab.lowercased() else { return false }
            
            // Filter by search text
            if searchText.isEmpty {
                return true
            }
            
            return merchant.name.localizedCaseInsensitiveContains(searchText) ||
                   merchant.contactEmail.localizedCaseInsensitiveContains(searchText) ||
                   merchant.id.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            MerchantContentView(
                searchText: $searchText,
                selectedMerchant: $selectedMerchant,
                showingAddMerchant: $showingAddMerchant,
                selectedTab: $selectedTab,
                filteredMerchants: filteredMerchants
            )
            .searchable(text: $searchText, prompt: "Search merchants...")
            .navigationTitle("Merchants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddMerchant = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMerchant) {
                MerchantOnboardingView(onMerchantCreated: { merchant in
                    // Add the new merchant to the model context
                    modelContext.insert(merchant)
                })
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedMerchant) { merchant in
                MerchantDetailSummaryView(merchant: merchant)
                    .presentationDragIndicator(.visible)
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .alert(errorMessage ?? "An error occurred", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadMerchants()
        }
    }
    
    private func loadMerchants() {
        isLoading = true
        
        Task {
            do {
                let fetchedMerchants = try await MerchantManager.shared.getMerchants()
                
                // Update SwiftData with the fetched merchants
                await MainActor.run {
                    // Remove existing merchants
                    for existingMerchant in merchants {
                        modelContext.delete(existingMerchant)
                    }
                    
                    // Insert new merchants
                    for merchant in fetchedMerchants {
                        modelContext.insert(merchant)
                    }
                    
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load merchants: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// Extract the content view to reduce complexity
struct MerchantContentView: View {
    @Binding var searchText: String
    @Binding var selectedMerchant: Merchant?
    @Binding var showingAddMerchant: Bool
    @Binding var selectedTab: String
    let filteredMerchants: [Merchant]
    
    var body: some View {
        VStack(spacing: 0) {
            // Merchant Overview Cards
            MerchantOverviewCardsView(merchants: filteredMerchants)
            
            // Merchant Status Tabs
            Picker("Status", selection: $selectedTab) {
                Text("Active").tag("Active")
                Text("Pending").tag("Pending")
                Text("Suspended").tag("Suspended")
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Merchant List
            MerchantListSummaryView(merchants: filteredMerchants, selectedMerchant: $selectedMerchant)
        }
        .ignoresSafeArea(edges: .horizontal)
    }
}

// Extract the overview cards to a separate view
struct MerchantOverviewCardsView: View {
    let merchants: [Merchant]
    
    private var totalMerchants: Int {
        merchants.count
    }
    
    private var pendingApproval: Int {
        merchants.filter { $0.status == .pending }.count
    }
    
    private var processingVolume: String {
        // Calculate total based on transactionFeePercentage as a proxy for volume
        let total = merchants.reduce(Decimal(0)) { sum, merchant in
            sum + (merchant.transactionFeePercentage * 10000) // Using fee as a proxy for volume
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "XCD"
        return formatter.string(from: NSDecimalNumber(decimal: total)) ?? "$0"
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                MetricCard(
                    title: "Total Merchants",
                    value: "\(totalMerchants)",
                    icon: "building.2.fill",
                    color: .blue
                )
                
                MetricCard(
                    title: "Pending Approval",
                    value: "\(pendingApproval)",
                    icon: "clock.fill",
                    color: .orange
                )
                
                MetricCard(
                    title: "Processing Volume",
                    value: processingVolume,
                    icon: "chart.line.uptrend.xyaxis.fill",
                    color: .green
                )
            }
            .padding()
        }
    }
}

// Extract the merchant list to a separate view
struct MerchantListSummaryView: View {
    let merchants: [Merchant]
    @Binding var selectedMerchant: Merchant?
    
    var body: some View {
        List {
            ForEach(merchants) { merchant in
                MerchantRow(merchant: merchant)
                    .onTapGesture {
                        selectedMerchant = merchant
                    }
            }
        }
        .listStyle(.plain)
        .overlay {
            if merchants.isEmpty {
                ContentUnavailableView(
                    "No Merchants Found",
                    systemImage: "building.2",
                    description: Text("Try adjusting your filters or add a new merchant")
                )
            }
        }
    }
}

struct MerchantRow: View {
    let merchant: Merchant
    
    var formattedVolume: String {
        // Using transactionFeePercentage as a proxy for volume
        let volume = merchant.transactionFeePercentage * 10000 // Example calculation
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "XCD"
        return formatter.string(from: NSDecimalNumber(decimal: volume)) ?? "$0"
    }
    
    var statusColor: Color {
        merchant.status.color
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: merchant.createdAt, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(merchant.name)
                    .font(.headline)
                Spacer()
                Text(merchant.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
            
            HStack {
                Label("ID: \(merchant.id.prefix(8))", systemImage: "number")
                Spacer()
                Label("Volume: \(formattedVolume)", systemImage: "chart.line.uptrend.xyaxis")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            HStack {
                if let address = merchant.address {
                    Label(address.components(separatedBy: ",").first ?? address, systemImage: "mappin")
                } else {
                    Label("No Address", systemImage: "mappin")
                }
                Spacer()
                Label("Created: \(timeAgo)", systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct MerchantDetailSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isLoading = false
    @State private var showingConfirmation = false
    @State private var errorMessage: String?
    @State private var actionType: MerchantAction = .suspend

    let merchant: Merchant
    
    enum MerchantAction {
        case suspend, activate, delete
    }
    
    // Helper function to parse country from address
    private func getCountryFromAddress() -> String {
        guard let address = merchant.address else { return "N/A" }
        let components = address.components(separatedBy: ",")
        guard let lastComponent = components.last else { return "N/A" }
        return lastComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Business Information") {
                    LabeledContent("Business Name", value: merchant.name)
                    LabeledContent("Registration No.", value: merchant.taxId ?? "N/A")
                    LabeledContent("Business Type", value: merchant.businessType)
                    LabeledContent("Country", value: getCountryFromAddress())
                }
                
                Section("Contact Information") {
                    LabeledContent("Email", value: merchant.contactEmail)
                    LabeledContent("Phone", value: merchant.contactPhone ?? "N/A")
                    LabeledContent("Address", value: merchant.address ?? "N/A")
                }
                
                Section("Processing") {
                    LabeledContent("Status", value: merchant.status.rawValue)
                    LabeledContent("Processing Fee", value: "\(merchant.transactionFeePercentage * 100)%")
                    LabeledContent("Settlement Period", value: "\(merchant.settlementPeriod) day(s)")
                    LabeledContent("Flat Fee", value: "\(merchant.flatFeeCents) cents")
                }
                
                Section("Integration") {
                    NavigationLink("API Keys") {
                        MerchantAPIKeysView(merchant: merchant)
                    }
                    
                    NavigationLink("Webhooks") {
                        Text("Webhooks")
                    }
                    
                    NavigationLink("Transaction History") {
                        MerchantTransactionsView(merchantId: merchant.id)
                    }
                }
                
                Section {
                    if merchant.status == .active {
                        Button("Suspend Merchant") {
                            actionType = .suspend
                            showingConfirmation = true
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.red)
                    } else if merchant.status == .suspended {
                        Button("Activate Merchant") {
                            actionType = .activate
                            showingConfirmation = true
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Merchant Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .alert(errorMessage ?? "An error occurred", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            }
            .confirmationDialog(
                actionType == .suspend ? "Suspend Merchant" : "Activate Merchant",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button(actionType == .suspend ? "Suspend" : "Activate", role: actionType == .suspend ? .destructive : .none) {
                    performMerchantAction()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(actionType == .suspend 
                     ? "Are you sure you want to suspend this merchant? They will no longer be able to process payments." 
                     : "Are you sure you want to activate this merchant? They will be able to process payments again.")
            }
        }
    }
    
    private func performMerchantAction() {
        isLoading = true
        
        Task {
            do {
                switch actionType {
                case .suspend:
                    try await MerchantManager.shared.suspendMerchant(id: merchant.id)
                    
                    await MainActor.run {
                        merchant.status = .suspended
                        try? modelContext.save()
                        isLoading = false
                    }
                case .activate:
                    try await MerchantManager.shared.activateMerchant(id: merchant.id)
                    
                    await MainActor.run {
                        merchant.status = .active
                        try? modelContext.save()
                        isLoading = false
                    }
                case .delete:
                    // Not implemented in this example
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to \(actionType == .suspend ? "suspend" : "activate") merchant: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct MerchantOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var businessName = ""
    @State private var registrationNumber = ""
    @State private var businessType = "Retail"
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var currentStep = 1
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let onMerchantCreated: (Merchant) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Indicator
                HStack {
                    ForEach(1...3, id: \.self) { step in
                        Circle()
                            .fill(step <= currentStep ? .blue : .gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding()
                
                TabView(selection: $currentStep) {
                    // Step 1: Business Information
                    Form {
                        Section("Business Information") {
                            TextField("Business Name", text: $businessName)
                            TextField("Registration Number", text: $registrationNumber)
                            Picker("Business Type", selection: $businessType) {
                                Text("Retail").tag("Retail")
                                Text("Restaurant").tag("Restaurant")
                                Text("Service").tag("Service")
                            }
                        }
                    }
                    .tag(1)
                    
                    // Step 2: Contact Information
                    Form {
                        Section("Contact Information") {
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                            
                            TextField("Phone", text: $phone)
                                .textContentType(.telephoneNumber)
                                .keyboardType(.phonePad)
                            
                            TextField("Address", text: $address)
                                .textContentType(.fullStreetAddress)
                        }
                    }
                    .tag(2)
                    
                    // Step 3: Review & Submit
                    Form {
                        Section("Review Information") {
                            LabeledContent("Business Name", value: businessName)
                            LabeledContent("Registration", value: registrationNumber)
                            LabeledContent("Business Type", value: businessType)
                            LabeledContent("Email", value: email)
                            LabeledContent("Phone", value: phone)
                            LabeledContent("Address", value: address)
                        }
                        
                        Section {
                            Button("Submit Application") {
                                submitMerchantApplication()
                            }
                            .frame(maxWidth: .infinity)
                            .disabled(isLoading)
                        }
                    }
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Navigation Buttons
                HStack {
                    if currentStep > 1 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .disabled(isLoading)
                    }
                    
                    Spacer()
                    
                    if currentStep < 3 {
                        Button("Next") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .disabled(isLoading)
                    }
                }
                .padding()
            }
            .navigationTitle("New Merchant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .alert(errorMessage ?? "An error occurred", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            }
        }
    }
    
    private func submitMerchantApplication() {
        guard !businessName.isEmpty, !email.isEmpty else {
            errorMessage = "Business name and email are required."
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let result = try await MerchantManager.shared.onboardMerchant(
                    name: businessName,
                    businessType: businessType,
                    contactEmail: email,
                    contactPhone: phone.isEmpty ? nil : phone,
                    address: address.isEmpty ? nil : address,
                    taxId: registrationNumber.isEmpty ? nil : registrationNumber
                )
                
                // MerchantOnboardingResult is a dictionary [String: String]
                guard let merchantId = result["merchantId"],
                      let merchantName = result["merchantName"],
                      let statusString = result["status"],
                      let status = MerchantStatus(rawValue: statusString) else {
                    throw NSError(domain: "MerchantError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid merchant data returned"])
                }
                
                // Create a local merchant object
                let merchant = Merchant(
                    id: merchantId,
                    name: merchantName,
                    businessType: businessType,
                    contactEmail: email,
                    contactPhone: phone.isEmpty ? nil : phone,
                    address: address.isEmpty ? nil : address,
                    island: .stKitts,
                    taxId: registrationNumber.isEmpty ? nil : registrationNumber,
                    status: status,
                    createdAt: Date()
                )
                
                await MainActor.run {
                    onMerchantCreated(merchant)
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create merchant: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// Placeholder views
struct MerchantAPIKeysView: View {
    let merchant: Merchant
    
    var body: some View {
        Text("API Keys for \(merchant.name)")
    }
}

struct MerchantTransactionsView: View {
    let merchantId: String
    
    var body: some View {
        Text("Transactions for Merchant ID: \(merchantId)")
    }
}

// struct Merchant is defined in MerchantManager.swift 
