import SwiftUI

struct MerchantListView: View {
    @StateObject private var viewModel = MerchantViewModel()
    @State private var showingAddMerchant = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.merchants.isEmpty {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if viewModel.merchants.isEmpty {
                    emptyStateView
                } else {
                    merchantList
                }
            }
            .navigationTitle("Merchants")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddMerchant = true
                    }) {
                        Label("Add Merchant", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.loadMerchants() }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Divider()
                        
                        // Filter options
                        Menu("Filter") {
                            Button("Show All", action: { /* Apply filter */ })
                            Button("Active Only", action: { /* Apply filter */ })
                            Button("Pending Only", action: { /* Apply filter */ })
                            Button("Suspended Only", action: { /* Apply filter */ })
                        }
                        
                        // Sort options
                        Menu("Sort") {
                            Button("Newest First", action: { /* Apply sort */ })
                            Button("Oldest First", action: { /* Apply sort */ })
                            Button("Name (A-Z)", action: { /* Apply sort */ })
                            Button("Name (Z-A)", action: { /* Apply sort */ })
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search merchants")
            .sheet(isPresented: $showingAddMerchant) {
                AddMerchantView(viewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError, presenting: viewModel.errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { errorMessage in
                Text(errorMessage)
            }
            .onAppear {
                viewModel.loadMerchants()
            }
        }
    }
    
    // Filtered merchants based on search text
    private var filteredMerchants: [Merchant] {
        if searchText.isEmpty {
            return viewModel.merchants
        } else {
            return viewModel.merchants.filter { merchant in
                merchant.name.localizedCaseInsensitiveContains(searchText) ||
                merchant.contactEmail.localizedCaseInsensitiveContains(searchText) ||
                merchant.businessType.localizedCaseInsensitiveContains(searchText) ||
                merchant.island.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Merchant list view
    private var merchantList: some View {
        List {
            ForEach(filteredMerchants) { merchant in
                NavigationLink(destination: MerchantDetailView(merchantId: merchant.id)) {
                    MerchantRowView(merchant: merchant)
                }
                .swipeActions(edge: .trailing) {
                    if merchant.status == .active {
                        Button(role: .destructive) {
                            viewModel.suspendMerchant(id: merchant.id)
                        } label: {
                            Label("Suspend", systemImage: "pause.circle")
                        }
                    } else if merchant.status == .suspended {
                        Button {
                            viewModel.activateMerchant(id: merchant.id)
                        } label: {
                            Label("Activate", systemImage: "play.circle")
                        }
                        .tint(.green)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await withCheckedContinuation { continuation in
                Task {
                    viewModel.loadMerchants()
                    continuation.resume()
                }
            }
        }
    }
    
    // Empty state view
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2")
                .font(.system(size: 80))
                .foregroundStyle(.tertiary)
            
            Text("No Merchants Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add your first merchant to start accepting payments.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                showingAddMerchant = true
            }) {
                Text("Add Merchant")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
        }
        .padding()
    }
}

struct MerchantRowView: View {
    let merchant: Merchant
    
    // Status color mapping
    private var statusColor: Color {
        switch merchant.status {
        case .active:
            return .green
        case .pending:
            return .orange
        case .suspended:
            return .red
        case .terminated:
            return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(merchant.name)
                    .font(.headline)
                
                Spacer()
                
                // Show merchant type icon
                Group {
                    switch merchant.merchantType {
                    case .pos:
                        Image(systemName: "creditcard.fill")
                    case .api:
                        Image(systemName: "network")
                    case .hybrid:
                        Image(systemName: "arrow.triangle.merge")
                    }
                }
                .foregroundColor(.secondary)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "building.2")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text(merchant.businessType)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(merchant.status.rawValue)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.1))
                .cornerRadius(12)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text(merchant.island.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// Placeholder for the detail view
struct MerchantDetailView: View {
    let merchantId: String
    @StateObject private var viewModel = MerchantViewModel()
    @State private var showingEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
                } else if let merchant = viewModel.selectedMerchant {
                    // Merchant Header
                    merchantHeaderView(merchant: merchant)
                    
                    Divider()
                    
                    // Merchant Details
                    merchantDetailsView(merchant: merchant)
                    
                    Divider()
                    
                    // Bank Information
                    if let bankAccount = merchant.bankAccount {
                        bankInformationView(bankAccount: bankAccount)
                        
                        Divider()
                    }
                    
                    // API Keys
                    apiKeysView(merchant: merchant)
                    
                    Divider()
                    
                    // POS Terminals (if applicable)
                    if merchant.merchantType == .pos || merchant.merchantType == .hybrid {
                        posTerminalsView(merchant: merchant)
                        
                        Divider()
                    }
                    
                    // Action Buttons
                    actionButtonsView(merchant: merchant)
                    
                    Spacer()
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.selectedMerchant?.name ?? "Merchant Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    viewModel.populateFormWithSelectedMerchant()
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditMerchantView(viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showError, presenting: viewModel.errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { errorMessage in
            Text(errorMessage)
        }
        .toast(isPresenting: $viewModel.showSuccess, duration: 2.0) {
            AlertToast(
                displayMode: .banner(.pop),
                type: .complete(.green),
                title: viewModel.successMessage
            )
        }
        .onAppear {
            viewModel.loadMerchantDetails(id: merchantId)
        }
    }
    
    // Merchant header with logo and basic info
    private func merchantHeaderView(merchant: Merchant) -> some View {
        HStack(spacing: 15) {
            // Merchant logo or placeholder
            if let logoUrl = merchant.logoUrl, !logoUrl.isEmpty {
                AsyncImage(url: URL(string: logoUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Text(String(merchant.name.prefix(1)))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(merchant.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(merchant.businessType)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 10) {
                    // Merchant type pill
                    Text(merchant.merchantType.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(10)
                    
                    // Status pill
                    Text(merchant.status.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(for: merchant.status).opacity(0.1))
                        .foregroundColor(statusColor(for: merchant.status))
                        .cornerRadius(10)
                }
            }
        }
        .padding(.vertical, 10)
    }
    
    // Merchant details section
    private func merchantDetailsView(merchant: Merchant) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Business Information", icon: "building.2")
            
            InfoRow(label: "Contact Email", value: merchant.contactEmail, systemImage: "envelope.fill")
            
            if let contactPhone = merchant.contactPhone {
                InfoRow(label: "Contact Phone", value: contactPhone, systemImage: "phone.fill")
            }
            
            if let address = merchant.address {
                InfoRow(label: "Address", value: address, systemImage: "location.fill")
            }
            
            InfoRow(label: "Island", value: merchant.island.rawValue, systemImage: "mappin.and.ellipse")
            
            if let taxId = merchant.taxId {
                InfoRow(label: "Tax ID", value: taxId, systemImage: "doc.text.fill")
            }
            
            if let websiteUrl = merchant.websiteUrl {
                InfoRow(label: "Website", value: websiteUrl, systemImage: "globe")
            }
            
            Spacer()
                .frame(height: 8)
            
            SectionHeader(title: "Pricing Configuration", icon: "dollarsign.circle.fill")
            
            InfoRow(
                label: "Transaction Fee",
                value: "\(formatPercentage(merchant.transactionFeePercentage)) + \(formatFlatFee(merchant.flatFeeCents))",
                systemImage: "percent"
            )
            
            InfoRow(
                label: "Settlement Period",
                value: "\(merchant.settlementPeriod) \(merchant.settlementPeriod == 1 ? "day" : "days")",
                systemImage: "calendar"
            )
        }
    }
    
    // Bank information section
    private func bankInformationView(bankAccount: BankAccount) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Bank Information", icon: "building.columns.fill")
            
            InfoRow(label: "Bank Name", value: bankAccount.bankName, systemImage: "building.columns")
            InfoRow(label: "Bank Type", value: bankAccount.bankType.rawValue, systemImage: "creditcard.fill")
            InfoRow(label: "Account Name", value: bankAccount.accountName, systemImage: "person.fill")
            InfoRow(label: "Account Number", value: maskAccountNumber(bankAccount.accountNumber), systemImage: "number")
            
            if let routingNumber = bankAccount.routingNumber {
                InfoRow(label: "Routing Number", value: routingNumber, systemImage: "arrow.triangle.branch")
            }
            
            if let iban = bankAccount.iban {
                InfoRow(label: "IBAN", value: iban, systemImage: "globe.europe.africa.fill")
            }
            
            if let swift = bankAccount.swift {
                InfoRow(label: "SWIFT/BIC", value: swift, systemImage: "network")
            }
        }
    }
    
    // API Keys section
    private func apiKeysView(merchant: Merchant) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "API Keys", icon: "key.fill")
                
                Spacer()
                
                Button(action: {
                    // Show sheet for generating new API key
                }) {
                    Label("New Key", systemImage: "plus")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            if let apiKeys = merchant.apiKeys, !apiKeys.isEmpty {
                ForEach(apiKeys) { key in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(key.name)
                                .font(.headline)
                                .foregroundColor(key.active ? .primary : .secondary)
                            
                            Spacer()
                            
                            Text(key.isLive ? "Live" : "Test")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(key.isLive ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                                .foregroundColor(key.isLive ? .green : .orange)
                                .cornerRadius(6)
                            
                            // Status pill
                            Text(key.active ? "Active" : "Revoked")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(key.active ? Color.blue.opacity(0.1) : Color.red.opacity(0.1))
                                .foregroundColor(key.active ? .blue : .red)
                                .cornerRadius(6)
                        }
                        
                        HStack(spacing: 8) {
                            Text(maskApiKey(key.key))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Button(action: {
                                UIPasteboard.general.string = key.key
                                viewModel.successMessage = "API key copied to clipboard"
                                viewModel.showSuccess = true
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                        }
                        
                        HStack {
                            Text("Created: \(formattedDate(key.createdAt))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if key.active {
                                Button(action: {
                                    viewModel.revokeApiKey(id: key.id, merchantId: merchant.id)
                                }) {
                                    Text("Revoke")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .padding(.vertical, 4)
                }
            } else {
                Text("No API keys generated yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
    
    // POS Terminals section
    private func posTerminalsView(merchant: Merchant) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "POS Terminals", icon: "creditcard.and.123")
                
                Spacer()
                
                Button(action: {
                    // Show sheet for adding new terminal
                }) {
                    Label("Add Terminal", systemImage: "plus")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            if let terminals = merchant.terminals, !terminals.isEmpty {
                ForEach(terminals) { terminal in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(terminal.model)
                                .font(.headline)
                            
                            Spacer()
                            
                            // Status pill
                            Text(terminal.isActive ? "Active" : "Inactive")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(terminal.isActive ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                .foregroundColor(terminal.isActive ? .green : .red)
                                .cornerRadius(6)
                        }
                        
                        HStack {
                            Image(systemName: "barcode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("S/N: \(terminal.serialNumber)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let location = terminal.location {
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(location)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("Activated: \(formattedDate(terminal.activationDate))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("Firmware: \(terminal.firmwareVersion)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .padding(.vertical, 4)
                }
            } else {
                Text("No POS terminals assigned yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
    
    // Action buttons section
    private func actionButtonsView(merchant: Merchant) -> some View {
        VStack(spacing: 15) {
            if merchant.status == .active {
                Button(action: {
                    viewModel.suspendMerchant(id: merchant.id)
                }) {
                    HStack {
                        Image(systemName: "pause.circle.fill")
                        Text("Suspend Merchant")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
            } else if merchant.status == .suspended {
                Button(action: {
                    viewModel.activateMerchant(id: merchant.id)
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Activate Merchant")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(10)
                }
            }
            
            Button(action: {
                // Navigate to transaction view
            }) {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                    Text("View Transactions")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Get color for status
    private func statusColor(for status: MerchantStatus) -> Color {
        switch status {
        case .active:
            return .green
        case .pending:
            return .orange
        case .suspended:
            return .red
        case .terminated:
            return .gray
        }
    }
    
    // Format percentage
    private func formatPercentage(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "\(decimal)%"
    }
    
    // Format flat fee
    private func formatFlatFee(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "XCD"
        
        return formatter.string(from: NSNumber(value: dollars)) ?? "$\(dollars)"
    }
    
    // Format date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return formatter.string(from: date)
    }
    
    // Mask account number
    private func maskAccountNumber(_ accountNumber: String) -> String {
        guard accountNumber.count > 4 else { return accountNumber }
        
        let lastFour = String(accountNumber.suffix(4))
        let maskedPart = String(repeating: "•", count: accountNumber.count - 4)
        
        return maskedPart + lastFour
    }
    
    // Mask API key
    private func maskApiKey(_ key: String) -> String {
        guard key.count > 8 else { return key }
        
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        let maskedPart = String(repeating: "•", count: 8)
        
        return prefix + maskedPart + suffix
    }
}

// MARK: - Helper Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.headline)
        }
        .padding(.vertical, 6)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let systemImage: String
    
    var body: some View {
        HStack(alignment: .top) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                
                Text(label)
                    .foregroundColor(.secondary)
            }
            .frame(width: 130, alignment: .leading)
            
            Text(value)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
        .padding(.vertical, 2)
    }
}

// MARK: - Placeholder AddMerchantView and EditMerchantView

struct AddMerchantView: View {
    @ObservedObject var viewModel: MerchantViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Add Merchant Form will go here")
                .navigationTitle("Add Merchant")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.createMerchant()
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct EditMerchantView: View {
    @ObservedObject var viewModel: MerchantViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Edit Merchant Form will go here")
                .navigationTitle("Edit Merchant")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.updateMerchant()
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - AlertToast for Success Messages

struct AlertToast: View {
    enum DisplayMode {
        case alert
        case hud
        case banner(BannerAnimation)
    }
    
    enum BannerAnimation {
        case slide
        case pop
    }
    
    enum AlertType {
        case complete(Color)
        case error(Color)
        case systemImage(String, Color)
        case image(String)
        case loading
    }
    
    var displayMode: DisplayMode
    var type: AlertType
    var title: String?
    
    var body: some View {
        VStack {
            switch displayMode {
            case .banner(let animation):
                switch animation {
                case .slide:
                    bannerView
                        .transition(.move(edge: .top))
                case .pop:
                    bannerView
                        .transition(.scale)
                }
            case .alert:
                alertView
                    .transition(.opacity)
            case .hud:
                hudView
                    .transition(.opacity)
            }
        }
    }
    
    private var bannerView: some View {
        HStack(spacing: 12) {
            iconView
            
            if let title = title {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    private var alertView: some View {
        VStack(spacing: 16) {
            iconView
                .frame(width: 50, height: 50)
            
            if let title = title {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 40)
    }
    
    private var hudView: some View {
        VStack(spacing: 16) {
            iconView
                .frame(width: 50, height: 50)
            
            if let title = title {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .padding(30)
    }
    
    @ViewBuilder
    private var iconView: some View {
        switch type {
        case .complete(let color):
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(color)
                .font(.system(size: 24, weight: .bold))
        case .error(let color):
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(color)
                .font(.system(size: 24, weight: .bold))
        case .systemImage(let name, let color):
            Image(systemName: name)
                .foregroundColor(color)
                .font(.system(size: 24, weight: .bold))
        case .image(let name):
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
        case .loading:
            ProgressView()
                .scaleEffect(1.5)
        }
    }
}

// MARK: - Toast View Modifier

extension View {
    func toast(isPresenting: Binding<Bool>, duration: Double = 2.0, tapToDismiss: Bool = true, @ViewBuilder content: @escaping () -> AlertToast) -> some View {
        self.modifier(ToastModifier(isPresenting: isPresenting, duration: duration, tapToDismiss: tapToDismiss, content: content))
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isPresenting: Bool
    let duration: Double
    let tapToDismiss: Bool
    @ViewBuilder let content: () -> AlertToast
    
    func body(content view: Content) -> some View {
        ZStack {
            view
            
            if isPresenting {
                ZStack {
                    self.content()
                        .onTapGesture {
                            if tapToDismiss {
                                withAnimation {
                                    isPresenting = false
                                }
                            }
                        }
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation {
                                    isPresenting = false
                                }
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Color.black.opacity(0.00001) // Invisible but captures taps if needed
                        .onTapGesture {
                            if tapToDismiss {
                                withAnimation {
                                    isPresenting = false
                                }
                            }
                        }
                )
                .edgesIgnoringSafeArea(.all)
            }
        }
    }
} 