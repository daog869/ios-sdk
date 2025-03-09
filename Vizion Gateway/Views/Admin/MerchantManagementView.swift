import SwiftUI
import SwiftData

enum MerchantStatus: String {
    case active = "Active"
    case pending = "Pending"
    case suspended = "Suspended"
    case terminated = "Terminated"
    
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
    @State private var searchText = ""
    @State private var selectedMerchant: Merchant?
    @State private var showingAddMerchant = false
    @State private var selectedTab = "Active"
    
    var body: some View {
        NavigationView {
            MerchantContentView(
                searchText: $searchText,
                selectedMerchant: $selectedMerchant,
                showingAddMerchant: $showingAddMerchant,
                selectedTab: $selectedTab
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
                MerchantOnboardingView()
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedMerchant) { merchant in
                MerchantDetailView(merchant: merchant)
                    .presentationDragIndicator(.visible)
            }
        }
        .navigationViewStyle(.stack)
    }
}

// Extract the content view to reduce complexity
struct MerchantContentView: View {
    @Binding var searchText: String
    @Binding var selectedMerchant: Merchant?
    @Binding var showingAddMerchant: Bool
    @Binding var selectedTab: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Merchant Overview Cards
            MerchantOverviewCardsView()
            
            // Merchant Status Tabs
            Picker("Status", selection: $selectedTab) {
                Text("Active").tag("Active")
                Text("Pending").tag("Pending")
                Text("Suspended").tag("Suspended")
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Merchant List
            MerchantListView(selectedMerchant: $selectedMerchant)
        }
        .ignoresSafeArea(edges: .horizontal)
    }
}

// Extract the overview cards to a separate view
struct MerchantOverviewCardsView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                MetricCard(
                    title: "Total Merchants",
                    value: "12",
                    icon: "building.2.fill",
                    color: .blue
                )
                
                MetricCard(
                    title: "Pending Approval",
                    value: "3",
                    icon: "clock.fill",
                    color: .orange
                )
                
                MetricCard(
                    title: "Processing Volume",
                    value: "$45,678",
                    icon: "chart.line.uptrend.xyaxis.fill",
                    color: .green
                )
            }
            .padding()
        }
    }
}

// Extract the merchant list to a separate view
struct MerchantListView: View {
    @Binding var selectedMerchant: Merchant?
    
    var body: some View {
        List {
            ForEach(0..<10) { index in
                MerchantRow()
                    .onTapGesture {
                        // Create a sample merchant with all required parameters
                        selectedMerchant = Merchant(
                            id: "M\(10000 + index)",
                            name: "Sample Merchant \(index + 1)",
                            businessType: "Retail",
                            contactEmail: "contact\(index + 1)@example.com",
                            contactPhone: "+1 869-123-\(4500 + index)",
                            address: "\(index + 1) Main Street, Basseterre",
                            taxId: "TAX\(10000 + index)",
                            status: "Active",
                            createdAt: Date()
                        )
                    }
            }
        }
        .listStyle(.plain)
    }
}

struct MerchantRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Merchant Name")
                    .font(.headline)
                Spacer()
                Text("Active")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }
            
            HStack {
                Label("ID: M12345", systemImage: "number")
                Spacer()
                Label("Volume: $12,345", systemImage: "chart.line.uptrend.xyaxis")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            HStack {
                Label("St. Kitts", systemImage: "mappin")
                Spacer()
                Label("Last active: 2h ago", systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct MerchantDetailView: View {
    let merchant: Merchant
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Business Information") {
                    LabeledContent("Business Name", value: "Sample Business")
                    LabeledContent("Registration No.", value: "REG123456")
                    LabeledContent("Business Type", value: "Retail")
                    LabeledContent("Country", value: "St. Kitts")
                }
                
                Section("Contact Information") {
                    LabeledContent("Email", value: "contact@sample.com")
                    LabeledContent("Phone", value: "+1 869-123-4567")
                    LabeledContent("Address", value: "123 Main St, Basseterre")
                }
                
                Section("Processing") {
                    LabeledContent("Status", value: "Active")
                    LabeledContent("Processing Volume", value: "$12,345")
                    LabeledContent("Transaction Limit", value: "$5,000")
                    LabeledContent("Processing Fee", value: "1.5%")
                }
                
                Section("Integration") {
                    NavigationLink("API Keys") {
                        Text("API Keys")
                    }
                    
                    NavigationLink("Webhooks") {
                        Text("Webhooks")
                    }
                    
                    NavigationLink("Transaction History") {
                        Text("Transaction History")
                    }
                }
                
                Section {
                    Button("Suspend Merchant") {
                        // Implement suspension
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.red)
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
                                // Submit merchant application
                                dismiss()
                            }
                            .frame(maxWidth: .infinity)
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
                    }
                    
                    Spacer()
                    
                    if currentStep < 3 {
                        Button("Next") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
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
                }
            }
        }
    }
}

// struct Merchant is defined in MerchantManager.swift 