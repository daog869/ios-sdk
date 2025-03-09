import SwiftUI
import SwiftData

struct SupportView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ChatSupportView()
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
                .tag(0)
            
            TicketListView()
                .tabItem {
                    Label("Tickets", systemImage: "ticket.fill")
                }
                .tag(1)
            
            KnowledgeBaseView()
                .tabItem {
                    Label("Help", systemImage: "book.fill")
                }
                .tag(2)
        }
        .navigationTitle("Support")
    }
}

// MARK: - Chat Support

struct ChatSupportView: View {
    @State private var messages: [ChatMessage] = []
    @State private var newMessage = ""
    @State private var isTyping = false
    @State private var showingAttachmentPicker = false
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        ChatBubble(message: message)
                    }
                    
                    if isTyping {
                        HStack {
                            Text("Support is typing...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            
            Divider()
            
            HStack {
                Button {
                    showingAttachmentPicker = true
                } label: {
                    Image(systemName: "paperclip")
                        .font(.title3)
                }
                .foregroundStyle(.blue)
                
                TextField("Type a message...", text: $newMessage)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(newMessage.isEmpty ? .gray : .blue)
                }
                .disabled(newMessage.isEmpty)
            }
            .padding()
        }
        .onAppear {
            simulateInitialMessage()
        }
    }
    
    private func simulateInitialMessage() {
        let welcome = ChatMessage(
            id: UUID(),
            content: "Hello! How can I help you today?",
            timestamp: Date(),
            isFromSupport: true
        )
        messages.append(welcome)
    }
    
    private func sendMessage() {
        let userMessage = ChatMessage(
            id: UUID(),
            content: newMessage,
            timestamp: Date(),
            isFromSupport: false
        )
        messages.append(userMessage)
        newMessage = ""
        
        // Simulate support response
        isTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let response = ChatMessage(
                id: UUID(),
                content: "Thank you for your message. A support representative will be with you shortly.",
                timestamp: Date(),
                isFromSupport: true
            )
            messages.append(response)
            isTyping = false
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromSupport {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: message.isFromSupport ? .leading : .trailing) {
                Text(message.content)
                    .padding()
                    .background(message.isFromSupport ? .gray.opacity(0.2) : .blue.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Text(message.timestamp, format: .dateTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if !message.isFromSupport {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isFromSupport ? .leading : .trailing)
    }
}

// MARK: - Ticket Management

struct TicketListView: View {
    @Query private var tickets: [SupportTicket]
    @State private var showingNewTicket = false
    @State private var searchText = ""
    
    var filteredTickets: [SupportTicket] {
        tickets.filter { ticket in
            searchText.isEmpty ||
            ticket.title.localizedCaseInsensitiveContains(searchText) ||
            ticket.ticketDescription.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredTickets) { ticket in
                NavigationLink {
                    TicketDetailView(ticket: ticket)
                } label: {
                    TicketRow(ticket: ticket)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search tickets...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewTicket = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewTicket) {
            NavigationView {
                NewTicketView()
            }
        }
    }
}

struct TicketRow: View {
    let ticket: SupportTicket
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ticket.title)
                    .font(.headline)
                Spacer()
                TicketStatusBadge(status: ticket.status)
            }
            
            Text(ticket.ticketDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            Text(ticket.createdAt, format: .dateTime)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct NewTicketView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var category: TicketCategory = .general
    
    var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                
                Picker("Category", selection: $category) {
                    ForEach(TicketCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                
                TextEditor(text: $description)
                    .frame(height: 100)
            }
            
            Section {
                Button("Submit Ticket") {
                    submitTicket()
                }
                .frame(maxWidth: .infinity)
                .disabled(title.isEmpty || description.isEmpty)
            }
        }
        .navigationTitle("New Support Ticket")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
    
    private func submitTicket() {
        let ticket = SupportTicket(
            title: title,
            description: description,
            category: category
        )
        modelContext.insert(ticket)
        dismiss()
    }
}

struct TicketDetailView: View {
    let ticket: SupportTicket
    @Environment(\.modelContext) private var modelContext
    @State private var newComment = ""
    
    var body: some View {
        List {
            Section("Ticket Details") {
                LabeledContent("Status", value: ticket.status.rawValue)
                LabeledContent("Category", value: ticket.category.rawValue)
                LabeledContent("Created", value: ticket.createdAt, format: .dateTime)
                if let updatedAt = ticket.updatedAt {
                    LabeledContent("Updated", value: updatedAt, format: .dateTime)
                }
            }
            
            Section {
                Text(ticket.ticketDescription)
            }
            
            if !ticket.comments.isEmpty {
                Section("Comments") {
                    ForEach(ticket.comments) { comment in
                        CommentRow(comment: comment)
                    }
                }
            }
            
            if ticket.status != .closed {
                Section {
                    TextField("Add comment...", text: $newComment)
                    
                    Button("Add Comment") {
                        addComment()
                    }
                    .disabled(newComment.isEmpty)
                    
                    if ticket.status == .open {
                        Button("Mark as In Progress") {
                            updateStatus(.inProgress)
                        }
                        .foregroundStyle(.blue)
                    }
                    
                    if ticket.status == .inProgress {
                        Button("Mark as Resolved") {
                            updateStatus(.resolved)
                        }
                        .foregroundStyle(.green)
                    }
                    
                    if ticket.status == .resolved {
                        Button("Close Ticket") {
                            updateStatus(.closed)
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(ticket.title)
    }
    
    private func addComment() {
        let comment = TicketComment(content: newComment)
        ticket.comments.append(comment)
        ticket.updatedAt = Date()
        newComment = ""
        try? modelContext.save()
    }
    
    private func updateStatus(_ newStatus: TicketStatus) {
        ticket.status = newStatus
        ticket.updatedAt = Date()
        try? modelContext.save()
    }
}

struct CommentRow: View {
    let comment: TicketComment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(comment.content)
            
            Text(comment.timestamp, format: .dateTime)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Knowledge Base

struct KnowledgeBaseView: View {
    @State private var searchText = ""
    let categories = KnowledgeCategory.allCases
    
    var body: some View {
        List {
            ForEach(categories) { category in
                NavigationLink {
                    ArticleListView(category: category)
                } label: {
                    CategoryRow(category: category)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search help articles...")
        .navigationTitle("Knowledge Base")
    }
}

struct CategoryRow: View {
    let category: KnowledgeCategory
    
    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading) {
                Text(category.title)
                    .font(.headline)
                
                Text(category.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ArticleListView: View {
    let category: KnowledgeCategory
    @State private var searchText = ""
    
    var filteredArticles: [KnowledgeArticle] {
        category.articles.filter { article in
            searchText.isEmpty ||
            article.title.localizedCaseInsensitiveContains(searchText) ||
            article.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List(filteredArticles) { article in
            NavigationLink {
                ArticleDetailView(article: article)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.title)
                        .font(.headline)
                    
                    Text(article.excerpt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
        }
        .searchable(text: $searchText, prompt: "Search articles...")
        .navigationTitle(category.title)
    }
}

struct ArticleDetailView: View {
    let article: KnowledgeArticle
    @State private var isHelpful: Bool?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.content)
                    .padding()
                
                Divider()
                
                VStack(spacing: 12) {
                    Text("Was this article helpful?")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        Button {
                            isHelpful = true
                        } label: {
                            Image(systemName: isHelpful == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.title2)
                        }
                        .foregroundStyle(isHelpful == true ? .green : .gray)
                        
                        Button {
                            isHelpful = false
                        } label: {
                            Image(systemName: isHelpful == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .font(.title2)
                        }
                        .foregroundStyle(isHelpful == false ? .red : .gray)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .navigationTitle(article.title)
    }
}

// MARK: - Supporting Types

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isFromSupport: Bool
}

@Model
class SupportTicket {
    var id: UUID
    var title: String
    var ticketDescription: String
    var status: TicketStatus
    var category: TicketCategory
    var createdAt: Date
    var updatedAt: Date?
    @Relationship(deleteRule: .cascade) var comments: [TicketComment]
    
    init(
        title: String,
        description: String,
        category: TicketCategory
    ) {
        self.id = UUID()
        self.title = title
        self.ticketDescription = description
        self.status = .open
        self.category = category
        self.createdAt = Date()
        self.comments = []
    }
}

@Model
class TicketComment {
    var id: UUID
    var content: String
    var timestamp: Date
    
    init(content: String) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
    }
}

enum TicketStatus: String, Codable {
    case open = "Open"
    case inProgress = "In Progress"
    case resolved = "Resolved"
    case closed = "Closed"
}

enum TicketCategory: String, Codable, CaseIterable, Identifiable {
    case general = "General"
    case technical = "Technical"
    case billing = "Billing"
    case account = "Account"
    
    var id: String { rawValue }
}

enum KnowledgeCategory: String, CaseIterable, Identifiable {
    case gettingStarted = "Getting Started"
    case payments = "Payments"
    case security = "Security"
    case troubleshooting = "Troubleshooting"
    
    var id: String { rawValue }
    
    var title: String { rawValue }
    
    var description: String {
        switch self {
        case .gettingStarted:
            return "Learn the basics of using VIZION Gateway"
        case .payments:
            return "Understanding payment methods and processes"
        case .security:
            return "Security features and best practices"
        case .troubleshooting:
            return "Common issues and solutions"
        }
    }
    
    var icon: String {
        switch self {
        case .gettingStarted: return "star.fill"
        case .payments: return "creditcard.fill"
        case .security: return "lock.fill"
        case .troubleshooting: return "wrench.fill"
        }
    }
    
    var articles: [KnowledgeArticle] {
        switch self {
        case .gettingStarted:
            return [
                KnowledgeArticle(
                    title: "Welcome to VIZION Gateway",
                    content: "VIZION Gateway is your trusted payment processing solution in St. Kitts and Nevis...",
                    excerpt: "Get started with VIZION Gateway"
                ),
                KnowledgeArticle(
                    title: "Setting Up Your Account",
                    content: "Follow these steps to set up your VIZION Gateway account...",
                    excerpt: "Account setup guide"
                )
            ]
        case .payments:
            return [
                KnowledgeArticle(
                    title: "Payment Methods",
                    content: "VIZION Gateway supports multiple payment methods including...",
                    excerpt: "Learn about available payment methods"
                ),
                KnowledgeArticle(
                    title: "Transaction Fees",
                    content: "Understanding VIZION Gateway's fee structure...",
                    excerpt: "Fee structure explanation"
                )
            ]
        case .security:
            return [
                KnowledgeArticle(
                    title: "Security Features",
                    content: "VIZION Gateway implements multiple security measures...",
                    excerpt: "Learn about our security features"
                ),
                KnowledgeArticle(
                    title: "Two-Factor Authentication",
                    content: "Protect your account with two-factor authentication...",
                    excerpt: "Enable 2FA for added security"
                )
            ]
        case .troubleshooting:
            return [
                KnowledgeArticle(
                    title: "Common Issues",
                    content: "Solutions to frequently encountered issues...",
                    excerpt: "Troubleshooting guide"
                ),
                KnowledgeArticle(
                    title: "Contact Support",
                    content: "Ways to get help when you need it...",
                    excerpt: "Support contact information"
                )
            ]
        }
    }
}

struct KnowledgeArticle: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let excerpt: String
}

struct TicketStatusBadge: View {
    let status: TicketStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        switch status {
        case .open:
            return .orange
        case .inProgress:
            return .blue
        case .resolved:
            return .green
        case .closed:
            return .red
        }
    }
}

#Preview {
    NavigationView {
        SupportView()
    }
    .modelContainer(for: [SupportTicket.self, TicketComment.self], inMemory: true)
} 