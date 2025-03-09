import SwiftUI
import SwiftData

struct ConnectedBanksView: View {
    @State private var banks = [
        "National Bank": "Connected",
        "RBTT Bank": "Connected",
        "First Caribbean": "Disconnected"
    ]
    @State private var showingAddBank = false
    
    var body: some View {
        List {
            ForEach(Array(banks.keys.sorted()), id: \.self) { bank in
                HStack {
                    Text(bank)
                    Spacer()
                    Text(banks[bank] ?? "")
                        .foregroundStyle(banks[bank] == "Connected" ? .green : .red)
                }
            }
        }
        .navigationTitle("Connected Banks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddBank = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct SettlementAccountsView: View {
    @State private var accounts = [
        "National Bank - ****1234": "Default",
        "RBTT Bank - ****5678": "Backup",
        "First Caribbean - ****9012": "Inactive"
    ]
    @State private var showingAddAccount = false
    
    var body: some View {
        List {
            ForEach(Array(accounts.keys.sorted()), id: \.self) { account in
                HStack {
                    Text(account)
                    Spacer()
                    Text(accounts[account] ?? "")
                        .foregroundStyle(accounts[account] == "Default" ? .blue : .secondary)
                }
            }
        }
        .navigationTitle("Settlement Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddAccount = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct APILogsView: View {
    @State private var logs: [APILog] = []
    @State private var searchText = ""
    @State private var isAutoRefreshing = true
    @State private var lastRefreshed = Date()
    @State private var selectedLogLevel: LogLevel?
    @State private var showingFilters = false
    @State private var dateRange: ClosedRange<Date>?
    
    var filteredLogs: [APILog] {
        logs.prefix(1000).filter { log in
            var matches = true
            
            if !searchText.isEmpty {
                matches = matches && log.message.localizedCaseInsensitiveContains(searchText)
            }
            
            if let level = selectedLogLevel {
                matches = matches && log.level == level
            }
            
            if let range = dateRange {
                matches = matches && range.contains(log.timestamp)
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
                ForEach(filteredLogs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(log.timestamp, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(log.level.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(log.level.color.opacity(0.2))
                                .foregroundStyle(log.level.color)
                                .clipShape(Capsule())
                        }
                        Text(log.message)
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
        .searchable(text: $searchText, prompt: "Search logs...")
        .navigationTitle("API Logs")
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
            LogFilterView(
                selectedLevel: $selectedLogLevel,
                dateRange: $dateRange
            )
            .presentationDragIndicator(.visible)
        }
        .task {
            // Auto-refresh every 5 seconds when enabled
            while isAutoRefreshing {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                // In a real app, fetch new logs here
                lastRefreshed = Date()
            }
        }
    }
}

struct LogFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLevel: LogLevel?
    @Binding var dateRange: ClosedRange<Date>?
    @State private var startDate = Date()
    @State private var endDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Log Level") {
                    Picker("Level", selection: $selectedLevel) {
                        Text("Any").tag(nil as LogLevel?)
                        ForEach(LogLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level as LogLevel?)
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
                        selectedLevel = nil
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

struct APILog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
}

enum LogLevel: String, CaseIterable {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    case debug = "DEBUG"
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .debug: return .gray
        }
    }
}

struct WebhookEventsView: View {
    @State private var events: [WebhookEvent] = []
    @State private var searchText = ""
    @State private var isAutoRefreshing = true
    @State private var lastRefreshed = Date()
    @State private var selectedEventType: EventType?
    @State private var showingFilters = false
    @State private var dateRange: ClosedRange<Date>?
    
    var filteredEvents: [WebhookEvent] {
        events.prefix(1000).filter { event in
            var matches = true
            
            if !searchText.isEmpty {
                matches = matches && (
                    event.type.rawValue.localizedCaseInsensitiveContains(searchText) ||
                    event.description.localizedCaseInsensitiveContains(searchText)
                )
            }
            
            if let type = selectedEventType {
                matches = matches && event.type == type
            }
            
            if let range = dateRange {
                matches = matches && range.contains(event.timestamp)
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
                ForEach(filteredEvents) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.timestamp, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(event.type.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(event.type.color.opacity(0.2))
                                .foregroundStyle(event.type.color)
                                .clipShape(Capsule())
                        }
                        Text(event.description)
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
        .searchable(text: $searchText, prompt: "Search events...")
        .navigationTitle("Webhook Events")
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
            EventFilterView(
                selectedType: $selectedEventType,
                dateRange: $dateRange
            )
            .presentationDragIndicator(.visible)
        }
        .task {
            // Auto-refresh every 5 seconds when enabled
            while isAutoRefreshing {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                // In a real app, fetch new events here
                lastRefreshed = Date()
            }
        }
    }
}

struct EventFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedType: EventType?
    @Binding var dateRange: ClosedRange<Date>?
    @State private var startDate = Date()
    @State private var endDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Type") {
                    Picker("Type", selection: $selectedType) {
                        Text("Any").tag(nil as EventType?)
                        ForEach(EventType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type as EventType?)
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
                        selectedType = nil
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

struct WebhookEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: EventType
    let description: String
}

enum EventType: String, CaseIterable {
    case transactionCreated = "transaction.created"
    case transactionCompleted = "transaction.completed"
    case transactionFailed = "transaction.failed"
    case bankConnected = "bank.connected"
    case bankDisconnected = "bank.disconnected"
    case systemStartup = "system.startup"
    case systemShutdown = "system.shutdown"
    
    var color: Color {
        switch self {
        case .transactionCreated: return .blue
        case .transactionCompleted: return .green
        case .transactionFailed: return .red
        case .bankConnected: return .purple
        case .bankDisconnected: return .orange
        case .systemStartup, .systemShutdown: return .gray
        }
    }
} 