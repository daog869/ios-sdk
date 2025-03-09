import SwiftUI
import SwiftData

struct APIKeysView: View {
    @State private var keys = [
        "Production": "pk_live_...",
        "Test": "pk_test_..."
    ]
    @State private var showingAddKey = false
    @State private var showingKeyReveal = false
    
    var body: some View {
        List {
            ForEach(Array(keys.keys.sorted()), id: \.self) { key in
                VStack(alignment: .leading) {
                    Text(key)
                        .font(.headline)
                    if showingKeyReveal {
                        Text(keys[key] ?? "")
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text("••••••••")
                    }
                }
            }
        }
        .navigationTitle("API Keys")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(showingKeyReveal ? "Hide" : "Show") {
                    showingKeyReveal.toggle()
                }
                
                Button {
                    showingAddKey = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct AccessLogsView: View {
    @State private var logs = [
        "2025-01-14 14:30:23 - Admin login from 192.168.1.1",
        "2025-01-14 14:29:45 - Settings updated",
        "2025-01-14 14:29:30 - Bank connection modified",
        "2025-01-14 14:29:15 - System startup"
    ]
    
    var body: some View {
        List {
            ForEach(logs, id: \.self) { log in
                Text(log)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .navigationTitle("Access Logs")
    }
}

struct ErrorLogsView: View {
    @State private var errors: [SystemError] = []
    @State private var searchText = ""
    @State private var isAutoRefreshing = true
    @State private var lastRefreshed = Date()
    @State private var selectedSeverity: ErrorSeverity?
    @State private var showingFilters = false
    @State private var dateRange: ClosedRange<Date>?
    
    var filteredErrors: [SystemError] {
        errors.prefix(1000).filter { error in
            var matches = true
            
            if !searchText.isEmpty {
                matches = matches && error.message.localizedCaseInsensitiveContains(searchText)
            }
            
            if let severity = selectedSeverity {
                matches = matches && error.severity == severity
            }
            
            if let range = dateRange {
                matches = matches && range.contains(error.timestamp)
            }
            
            return matches
        }
    }
    
    var body: some View {
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
            
            List {
                ForEach(filteredErrors) { error in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(error.timestamp, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(error.severity.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(error.severity.color.opacity(0.2))
                                .foregroundStyle(error.severity.color)
                                .clipShape(Capsule())
                        }
                        Text(error.message)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(error.severity.color)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
        .searchable(text: $searchText, prompt: "Search errors...")
        .navigationTitle("Error Logs")
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
            ErrorFilterView(
                selectedSeverity: $selectedSeverity,
                dateRange: $dateRange
            )
            .presentationDragIndicator(.visible)
        }
        .task {
            // Auto-refresh every 5 seconds when enabled
            while isAutoRefreshing {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                // In a real app, fetch new errors here
                lastRefreshed = Date()
            }
        }
    }
}

struct ErrorFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSeverity: ErrorSeverity?
    @Binding var dateRange: ClosedRange<Date>?
    @State private var startDate = Date()
    @State private var endDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Error Severity") {
                    Picker("Severity", selection: $selectedSeverity) {
                        Text("Any").tag(nil as ErrorSeverity?)
                        ForEach(ErrorSeverity.allCases, id: \.self) { severity in
                            Text(severity.rawValue).tag(severity as ErrorSeverity?)
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
                        selectedSeverity = nil
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

struct SystemError: Identifiable {
    let id = UUID()
    let timestamp: Date
    let severity: ErrorSeverity
    let message: String
}

enum ErrorSeverity: String, CaseIterable {
    case critical = "CRITICAL"
    case error = "ERROR"
    case warning = "WARNING"
    case info = "INFO"
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .error: return .orange
        case .warning: return .yellow
        case .info: return .blue
        }
    }
}

struct SystemStatusView: View {
    @State private var selectedTab = "Status"
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(["Status", "Performance", "Logs"], id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(tab)
                                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .background(.bar)
            
            Divider()
            
            // Content
            TabView(selection: $selectedTab) {
                SystemOverviewView()
                    .tag("Status")
                
                SystemPerformanceView()
                    .tag("Performance")
                
                SystemLogsView()
                    .tag("Logs")
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("System")
    }
}

struct SystemOverviewView: View {
    @State private var services = [
        "Bank Connection": "Online",
        "API Gateway": "Online",
        "Database": "Online",
        "Webhook Service": "Degraded"
    ]
    
    var body: some View {
        List {
            Section("Services") {
                ForEach(Array(services.keys.sorted()), id: \.self) { service in
                    HStack {
                        Text(service)
                        Spacer()
                        HStack {
                            Circle()
                                .fill(statusColor(services[service] ?? ""))
                                .frame(width: 8, height: 8)
                            Text(services[service] ?? "")
                        }
                        .foregroundStyle(statusColor(services[service] ?? ""))
                    }
                }
            }
            
            Section("System Info") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Last Update", value: "2025-01-14 14:30:23")
                LabeledContent("Environment", value: "Production")
                LabeledContent("Region", value: "St. Kitts")
            }
        }
        .listStyle(.plain)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Online": return .green
        case "Degraded": return .orange
        case "Offline": return .red
        default: return .gray
        }
    }
}

struct SystemPerformanceView: View {
    @State private var cpuUsage = 23.0
    @State private var memoryUsage = 512.0
    @State private var storageUsage = 2.1
    @State private var uptime = "5d 12h 30m"
    
    var body: some View {
        List {
            Section("Resources") {
                VStack(spacing: 16) {
                    UsageGauge(title: "CPU", value: cpuUsage, unit: "%", color: gaugeColor(cpuUsage))
                    UsageGauge(title: "Memory", value: memoryUsage, unit: "MB", color: gaugeColor(memoryUsage/1024*100))
                    UsageGauge(title: "Storage", value: storageUsage, unit: "GB", color: gaugeColor(storageUsage/10*100))
                }
                .padding(.vertical)
            }
            
            Section("System Load") {
                LabeledContent("Uptime", value: uptime)
                LabeledContent("Active Users", value: "12")
                LabeledContent("Requests/min", value: "156")
                LabeledContent("Avg Response", value: "235ms")
            }
        }
        .listStyle(.plain)
    }
    
    private func gaugeColor(_ percentage: Double) -> Color {
        switch percentage {
        case 0..<60: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

struct UsageGauge: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
            
            Gauge(value: value/100) {
                EmptyView()
            }
            .gaugeStyle(.accessoryCircular)
            .tint(color)
            .scaleEffect(1.5)
            
            Text("\(value, specifier: "%.1f")\(unit)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct SystemLogsView: View {
    @State private var selectedLogType = 0
    @State private var searchText = ""
    @State private var isAutoRefreshing = true
    @State private var showingFilters = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Log type selector
            Picker("Log Type", selection: $selectedLogType) {
                Text("API").tag(0)
                Text("Access").tag(1)
                Text("Error").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Status bar
            HStack {
                Circle()
                    .fill(isAutoRefreshing ? .green : .secondary)
                    .frame(width: 8, height: 8)
                Text(isAutoRefreshing ? "Live" : "Paused")
                    .font(.caption)
                Spacer()
                Text("Last updated: \(Date().formatted(.relative(presentation: .named)))")
                    .font(.caption)
            }
            .padding(.horizontal)
            
            // Log content
            TabView(selection: $selectedLogType) {
                APILogsView()
                    .tag(0)
                
                AccessLogsView()
                    .tag(1)
                
                ErrorLogsView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .searchable(text: $searchText, prompt: "Search logs...")
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
    }
}

struct SystemSettingsView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Section", selection: $selectedTab) {
                    Text("Status").tag(0)
                    Text("Performance").tag(1)
                    Text("Logs").tag(2)
                    Text("Settings").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                TabView(selection: $selectedTab) {
                    // Status Tab
                    SystemStatusView()
                        .tag(0)
                    
                    // Performance Tab
                    SystemPerformanceView()
                        .tag(1)
                    
                    // Logs Tab
                    SystemLogsView()
                        .tag(2)
                    
                    // Settings Tab
                    List {
                        Section("Processing Settings") {
                            Toggle("Auto-retry failed transactions", isOn: .constant(true))
                            Toggle("Real-time fraud detection", isOn: .constant(true))
                            Toggle("Require 2FA for large transactions", isOn: .constant(true))
                        }
                        
                        Section("Security") {
                            Toggle("IP whitelisting", isOn: .constant(true))
                            Toggle("Rate limiting", isOn: .constant(true))
                            Toggle("Audit logging", isOn: .constant(true))
                        }
                        
                        Section("System") {
                            Toggle("Auto backup", isOn: .constant(true))
                            Toggle("Debug mode", isOn: .constant(false))
                            Toggle("Maintenance mode", isOn: .constant(false))
                        }
                    }
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("System")
        }
        .navigationViewStyle(.stack)
    }
} 