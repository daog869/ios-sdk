import SwiftUI
import FirebaseFirestore

struct VerificationManagementView: View {
    @StateObject private var viewModel = VerificationManagementViewModel()
    @State private var showingVerificationDetails = false
    @State private var selectedVerification: VerificationRecord?
    @State private var selectedStatus: KYCVerificationStatus?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.verifications.isEmpty {
                    ProgressView("Loading verifications...")
                        .progressViewStyle(.circular)
                } else if viewModel.verifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.blue.opacity(0.7))
                        
                        Text("No Verification Requests")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("When users submit verification requests, they will appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.statusOptions, id: \.self) { status in
                            let filteredVerifications = viewModel.verifications.filter { $0.status == status }
                            if !filteredVerifications.isEmpty {
                                Section(header: Text(status.rawValue)) {
                                    ForEach(filteredVerifications) { verification in
                                        Button {
                                            selectedVerification = verification
                                            showingVerificationDetails = true
                                        } label: {
                                            VerificationRow(verification: verification)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.loadVerifications()
                    }
                }
            }
            .navigationTitle("Identity Verifications")
            .sheet(isPresented: $showingVerificationDetails) {
                if let verification = selectedVerification {
                    VerificationDetailView(verification: verification)
                        .environmentObject(viewModel)
                }
            }
            .task {
                await viewModel.loadVerifications()
            }
        }
    }
}

struct VerificationRow: View {
    let verification: VerificationRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(verification.status.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(verification.userName)
                    .font(.headline)
                
                Text(verification.userId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let createdAt = verification.createdAt {
                    Text("Submitted: \(dateFormatter.string(from: createdAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Risk indicator
            if verification.riskScore > 0 {
                HStack(spacing: 4) {
                    Text("Risk: \(verification.riskScore)")
                        .font(.caption.bold())
                        .foregroundStyle(riskColor)
                    
                    Circle()
                        .fill(riskColor)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(riskColor.opacity(0.1))
                .clipShape(Capsule())
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var riskColor: Color {
        if verification.riskScore >= 75 {
            return .red
        } else if verification.riskScore >= 50 {
            return .orange
        } else if verification.riskScore >= 25 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct VerificationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: VerificationManagementViewModel
    let verification: VerificationRecord
    
    @State private var approvalNotes = ""
    @State private var rejectionReason = ""
    @State private var additionalItems: [String] = []
    @State private var newAdditionalItem = ""
    @State private var showApproveAlert = false
    @State private var showRejectAlert = false
    @State private var showRequestInfoAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Status section
                        HStack {
                            Spacer()
                            
                            VStack(spacing: 8) {
                                Text(verification.status.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(verification.status.color)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(verification.status.color.opacity(0.1))
                                    .clipShape(Capsule())
                                
                                if verification.riskScore > 0 {
                                    Text("Risk Score: \(verification.riskScore)")
                                        .font(.caption.bold())
                                        .foregroundStyle(riskColor)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(riskColor.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.bottom)
                        
                        // User details
                        VStack(alignment: .leading, spacing: 8) {
                            Text("User Information")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                VerificationInfoRow(title: "Name", value: verification.userName)
                                Divider()
                                VerificationInfoRow(title: "User ID", value: verification.userId)
                                Divider()
                                VerificationInfoRow(title: "Submitted", value: verification.createdAt?.formatted(date: .long, time: .shortened) ?? "Unknown")
                                
                                if let updated = verification.updatedAt {
                                    Divider()
                                    VerificationInfoRow(title: "Last Updated", value: updated.formatted(date: .long, time: .shortened))
                                }
                            }
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal)
                        }
                        
                        // Verification steps
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Verification Steps")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(verification.steps, id: \.id) { step in
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(step.isCompleted ? Color.green : Color.gray.opacity(0.2))
                                            .frame(width: 24, height: 24)
                                        
                                        if step.isCompleted {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(step.name)
                                            .font(.subheadline.bold())
                                        
                                        if let timestamp = step.timestamp {
                                            Text("Completed: \(timestamp.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal)
                            }
                        }
                        
                        // User documents
                        if let documents = verification.documents, !documents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Uploaded Documents")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(Array(documents.keys), id: \.self) { key in
                                    if let docValue = documents[key] as? [String: Any] {
                                        DocumentRow(documentType: key, document: docValue)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        
                        // AML Screening data
                        if let screeningData = verification.screeningData {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("AML Screening")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    VerificationInfoRow(title: "Full Name", value: screeningData.fullName)
                                    Divider()
                                    VerificationInfoRow(title: "Date of Birth", value: screeningData.dateOfBirth.formatted(date: .long, time: .omitted))
                                    Divider()
                                    VerificationInfoRow(title: "Nationality", value: screeningData.nationality)
                                    Divider()
                                    VerificationInfoRow(title: "Address", value: screeningData.address)
                                    Divider()
                                    VerificationInfoRow(title: "Occupation", value: screeningData.occupation)
                                    Divider()
                                    VerificationInfoRow(title: "Source of Funds", value: screeningData.sourceOfFunds)
                                    Divider()
                                    VerificationInfoRow(title: "PEP Status", value: screeningData.isPep ? "Yes - PEP" : "Not a PEP")
                                }
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal)
                            }
                        }
                        
                        // Admin notes section (only for approving)
                        if verification.status != .verified && verification.status != .rejected {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Admin Notes")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                TextEditor(text: $approvalNotes)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Rejection reason (only when rejecting)
                        if verification.status != .verified && verification.status != .rejected {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Rejection Reason")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                TextEditor(text: $rejectionReason)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Additional information section
                        if verification.status != .verified && verification.status != .rejected {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Request Additional Information")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(additionalItems, id: \.self) { item in
                                    HStack {
                                        Text(item)
                                        Spacer()
                                        Button {
                                            if let index = additionalItems.firstIndex(of: item) {
                                                additionalItems.remove(at: index)
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                }
                                
                                HStack {
                                    TextField("New required item", text: $newAdditionalItem)
                                        .padding()
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .cornerRadius(10)
                                    
                                    Button {
                                        if !newAdditionalItem.isEmpty {
                                            additionalItems.append(newAdditionalItem)
                                            newAdditionalItem = ""
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Action buttons
                        if verification.status != .verified && verification.status != .rejected {
                            HStack(spacing: 16) {
                                // Reject
                                Button {
                                    showRejectAlert = true
                                } label: {
                                    Text("Reject")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(10)
                                }
                                
                                // Request More Info
                                Button {
                                    showRequestInfoAlert = true
                                } label: {
                                    Text("Request Info")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.orange)
                                        .cornerRadius(10)
                                }
                                .disabled(additionalItems.isEmpty)
                                
                                // Approve
                                Button {
                                    showApproveAlert = true
                                } label: {
                                    Text("Approve")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .cornerRadius(10)
                                }
                            }
                            .padding()
                        }
                    }
                    .padding(.vertical)
                }
                
                if viewModel.isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(1.5)
                                .tint(.white)
                        )
                }
            }
            .navigationTitle("Verification Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Approve Verification", isPresented: $showApproveAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Approve", role: .destructive) {
                    Task {
                        await viewModel.approveVerification(
                            userId: verification.userId,
                            notes: approvalNotes
                        )
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to approve this verification? This will grant the user full access to the platform.")
            }
            .alert("Reject Verification", isPresented: $showRejectAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reject", role: .destructive) {
                    Task {
                        if !rejectionReason.isEmpty {
                            await viewModel.rejectVerification(
                                userId: verification.userId,
                                reason: rejectionReason
                            )
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to reject this verification? The user will be notified and asked to restart the process.")
            }
            .alert("Request Additional Information", isPresented: $showRequestInfoAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Request Info", role: .destructive) {
                    Task {
                        if !additionalItems.isEmpty {
                            await viewModel.requestAdditionalInformation(
                                userId: verification.userId,
                                items: additionalItems
                            )
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Request the user to provide additional information? They will be notified about the required items.")
            }
        }
    }
    
    private var riskColor: Color {
        if verification.riskScore >= 75 {
            return .red
        } else if verification.riskScore >= 50 {
            return .orange
        } else if verification.riskScore >= 25 {
            return .yellow
        } else {
            return .green
        }
    }
}

struct VerificationInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct DocumentRow: View {
    let documentType: String
    let document: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Document type icon
                Image(systemName: "doc.text.viewfinder")
                    .foregroundStyle(.blue)
                
                // Document type name
                Text(formatDocumentType(documentType))
                    .font(.headline)
                
                Spacer()
                
                // Verification status
                if (document["verified"] as? Bool) == true {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.orange)
                }
            }
            
            // Document upload date
            if let timestamp = document["uploadedAt"] as? Timestamp {
                Text("Uploaded: \(timestamp.dateValue().formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Document URL and preview button
            if let url = document["url"] as? String, let urlObj = URL(string: url) {
                Link(destination: urlObj) {
                    Text("View Document")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func formatDocumentType(_ type: String) -> String {
        // Convert from types like "identity_passport" to "Passport"
        let components = type.split(separator: "_")
        if components.count >= 2 {
            let docType = components[1]
            let capitalized = docType.prefix(1).uppercased() + docType.dropFirst()
            
            // Further improve readability
            return capitalized
                .replacingOccurrences(of: "Passport", with: "Passport")
                .replacingOccurrences(of: "Drivers", with: "Driver's")
                .replacingOccurrences(of: "Driverslicense", with: "Driver's License")
                .replacingOccurrences(of: "License", with: "License")
                .replacingOccurrences(of: "National", with: "National ID")
                .replacingOccurrences(of: "Utility", with: "Utility Bill")
                .replacingOccurrences(of: "Bank", with: "Bank Statement")
        }
        
        // Fallback to original with underscores replaced by spaces
        return type.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - ViewModel

class VerificationManagementViewModel: ObservableObject {
    @Published var verifications: [VerificationRecord] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let kycManager = AMLKYCManager.shared
    private let db = Firestore.firestore()
    
    // Order of statuses for display
    let statusOptions: [KYCVerificationStatus] = [
        .documentVerificationPending,
        .underReview,
        .enhancedDueDiligence,
        .additionalInformationRequired,
        .inProgress,
        .verified,
        .rejected,
        .notStarted
    ]
    
    func loadVerifications() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let snapshot = try await db.collection("verifications")
                .order(by: "updatedAt", descending: true)
                .getDocuments()
            
            let records = snapshot.documents.compactMap { document -> VerificationRecord? in
                let data = document.data()
                
                guard let userId = data["userId"] as? String,
                      let statusString = data["status"] as? String,
                      let status = KYCVerificationStatus(rawValue: statusString) else {
                    return nil
                }
                
                // Fetch user's name from the document or lookup user details
                return VerificationRecord(
                    id: document.documentID,
                    userId: userId,
                    userName: data["userName"] as? String ?? "Unknown User",
                    status: status,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue(),
                    riskScore: data["riskScore"] as? Int ?? 0,
                    steps: parseSteps(data),
                    documents: data["documents"] as? [String: [String: Any]],
                    screeningData: parseScreeningData(data),
                    adminNotes: data["adminNotes"] as? String,
                    rejectionReason: data["rejectionReason"] as? String,
                    requestedItems: data["requestedItems"] as? [String]
                )
            }
            
            await MainActor.run {
                self.verifications = records
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            print("Error loading verifications: \(error.localizedDescription)")
        }
    }
    
    func approveVerification(userId: String, notes: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await kycManager.approveVerification(for: userId, notes: notes)
            
            // Refresh the list
            await loadVerifications()
        } catch {
            print("Error approving verification: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func rejectVerification(userId: String, reason: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await kycManager.rejectVerification(for: userId, reason: reason)
            
            // Refresh the list
            await loadVerifications()
        } catch {
            print("Error rejecting verification: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func requestAdditionalInformation(userId: String, items: [String]) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await kycManager.requestAdditionalInformation(for: userId, requestedItems: items)
            
            // Refresh the list
            await loadVerifications()
        } catch {
            print("Error requesting additional information: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseSteps(_ data: [String: Any]) -> [VerificationStep] {
        guard let steps = data["steps"] as? [[String: Any]] else {
            return []
        }
        
        return steps.compactMap { stepData in
            guard let id = stepData["id"] as? String,
                  let name = stepData["name"] as? String,
                  let completed = stepData["completed"] as? Bool else {
                return nil
            }
            
            return VerificationStep(
                id: id,
                name: name,
                description: stepData["description"] as? String,
                isCompleted: completed,
                timestamp: (stepData["timestamp"] as? Timestamp)?.dateValue()
            )
        }
    }
    
    private func parseScreeningData(_ data: [String: Any]) -> ScreeningData? {
        guard let screeningData = data["screeningData"] as? [String: Any],
              let fullName = screeningData["fullName"] as? String,
              let dateOfBirth = (screeningData["dateOfBirth"] as? Timestamp)?.dateValue(),
              let nationality = screeningData["nationality"] as? String,
              let address = screeningData["address"] as? String,
              let occupation = screeningData["occupation"] as? String,
              let sourceOfFunds = screeningData["sourceOfFunds"] as? String,
              let isPep = screeningData["isPep"] as? Bool else {
            return nil
        }
        
        return ScreeningData(
            fullName: fullName,
            dateOfBirth: dateOfBirth,
            nationality: nationality,
            address: address,
            occupation: occupation,
            sourceOfFunds: sourceOfFunds,
            isPep: isPep
        )
    }
}

// MARK: - Models

struct VerificationRecord: Identifiable {
    let id: String
    let userId: String
    let userName: String
    let status: KYCVerificationStatus
    let createdAt: Date?
    let updatedAt: Date?
    let riskScore: Int
    let steps: [VerificationStep]
    let documents: [String: [String: Any]]?
    let screeningData: ScreeningData?
    let adminNotes: String?
    let rejectionReason: String?
    let requestedItems: [String]?
}

struct ScreeningData {
    let fullName: String
    let dateOfBirth: Date
    let nationality: String
    let address: String
    let occupation: String
    let sourceOfFunds: String
    let isPep: Bool
}

struct VerificationManagementView_Previews: PreviewProvider {
    static var previews: some View {
        VerificationManagementView()
    }
} 