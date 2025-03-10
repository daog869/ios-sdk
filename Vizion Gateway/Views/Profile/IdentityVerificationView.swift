import SwiftUI
import PhotosUI
import FirebaseFirestore

struct IdentityVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = IdentityVerificationViewModel()
    @State private var currentStep = 0
    @State private var selectedDocumentType: DocumentType = .identityPassport
    @State private var showCameraSheet = false
    @State private var showPhotosPicker = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var capturedImage: UIImage?
    @State private var showCompletionView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Verification progress
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                        .padding(.horizontal)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Header section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Identity Verification")
                                    .font(.title2.bold())
                                
                                Text(viewModel.statusDescription)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            // Status badge
                            HStack {
                                Spacer()
                                statusBadge
                                Spacer()
                            }
                            
                            // Steps list
                            stepsView
                                .padding(.top, 8)
                            
                            // Document upload section
                            if viewModel.status == .notStarted || viewModel.status == .inProgress {
                                documentUploadSection
                                    .padding(.top, 8)
                            }
                            
                            // Action buttons
                            VStack(spacing: 16) {
                                if viewModel.status == .notStarted || viewModel.status == .inProgress {
                                    Button(action: startOrContinueVerification) {
                                        Text(viewModel.status == .notStarted ? "Start Verification" : "Continue Verification")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.blue)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .padding(.horizontal)
                                }
                                
                                if viewModel.status == .rejected {
                                    Button(action: restartVerification) {
                                        Text("Restart Verification")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.blue)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .padding(.horizontal)
                                }
                                
                                Button(action: { dismiss() }) {
                                    Text("Back to Profile")
                                        .font(.headline)
                                        .foregroundStyle(.blue)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                        .padding(.bottom, 24)
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.4))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Identity Verification")
                        .font(.headline)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCameraSheet) {
                CameraView(image: $capturedImage, onCapture: uploadCapturedImage)
            }
            .photosPicker(isPresented: $showPhotosPicker, selection: $selectedItems, matching: .images)
            .onChange(of: selectedItems) { newItems in
                Task {
                    if let first = newItems.first {
                        if let data = try? await first.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            capturedImage = image
                            uploadCapturedImage()
                        }
                    }
                }
            }
            .onChange(of: viewModel.status) { newStatus in
                if newStatus == .verified {
                    showCompletionView = true
                }
            }
            .fullScreenCover(isPresented: $showCompletionView) {
                VerificationCompletedView {
                    dismiss()
                }
            }
            .alert("Verification Error", isPresented: .init(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .task {
                if let userId = AuthorizationManager.shared.currentUser?.id {
                    await viewModel.loadVerificationStatus(userId: userId)
                }
            }
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.statusColor)
                .frame(width: 8, height: 8)
            
            Text(viewModel.status.rawValue)
                .font(.footnote.bold())
                .foregroundStyle(viewModel.statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(viewModel.statusColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var stepsView: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.steps) { step in
                HStack {
                    ZStack {
                        Circle()
                            .fill(step.isCompleted ? Color.green : Color.gray.opacity(0.2))
                            .frame(width: 24, height: 24)
                        
                        if step.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(viewModel.steps.firstIndex(where: { $0.id == step.id })?.advanced(by: 1) ?? 0)")
                                .font(.caption.bold())
                                .foregroundStyle(.gray)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.name)
                            .font(.subheadline.bold())
                        
                        if let description = step.description {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if step.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }
    
    private var documentUploadSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upload Your Documents")
                .font(.headline)
                .padding(.horizontal)
            
            Picker("Document Type", selection: $selectedDocumentType) {
                ForEach(DocumentType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            // Document description
            Text(selectedDocumentType.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            // Upload buttons
            HStack(spacing: 12) {
                Button(action: { showCameraSheet = true }) {
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text("Take Photo")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: { showPhotosPicker = true }) {
                    VStack {
                        Image(systemName: "photo.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text("Upload Photo")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            
            // Preview
            if let image = capturedImage {
                HStack {
                    Spacer()
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    private func startOrContinueVerification() {
        Task {
            if let userId = AuthorizationManager.shared.currentUser?.id {
                await viewModel.startVerification(userId: userId)
            }
        }
    }
    
    private func restartVerification() {
        Task {
            if let userId = AuthorizationManager.shared.currentUser?.id {
                await viewModel.restartVerification(userId: userId)
            }
        }
    }
    
    private func uploadCapturedImage() {
        Task {
            if let userId = AuthorizationManager.shared.currentUser?.id,
               let image = capturedImage {
                await viewModel.uploadDocument(userId: userId, documentType: selectedDocumentType, image: image)
                capturedImage = nil
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onCapture: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.onCapture()
            }
            
            picker.dismiss(animated: true)
        }
    }
}

struct VerificationCompletedView: View {
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .padding()
            
            Text("Verification Complete!")
                .font(.title.bold())
            
            Text("Your identity has been successfully verified. You now have full access to all features.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: onDismiss) {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 32)
            }
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - ViewModel

class IdentityVerificationViewModel: ObservableObject {
    @Published var status: VerificationStatus = .notStarted
    @Published var progress: Double = 0.0
    @Published var steps: [VerificationStep] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let kycManager = AMLKYCManager.shared
    
    var statusColor: Color {
        status.color
    }
    
    var statusDescription: String {
        status.description
    }
    
    func loadVerificationStatus(userId: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let status = try await kycManager.getVerificationStatus(for: userId)
            
            await MainActor.run {
                self.status = status
                self.progress = kycManager.verificationProgress
                self.steps = kycManager.verificationSteps
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load verification status: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func startVerification(userId: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Update status to in progress
            let db = Firestore.firestore()
            try await db.collection("verifications").document(userId).updateData([
                "status": VerificationStatus.inProgress.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            await loadVerificationStatus(userId: userId)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to start verification: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func restartVerification(userId: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Delete existing verification document
            let db = Firestore.firestore()
            try await db.collection("verifications").document(userId).delete()
            
            // Load fresh verification status (which will create a new document)
            await loadVerificationStatus(userId: userId)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to restart verification: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func uploadDocument(userId: String, documentType: DocumentType, image: UIImage) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            _ = try await kycManager.uploadIdentityDocument(userId: userId, documentType: documentType, image: image)
            
            // Refresh verification status
            await loadVerificationStatus(userId: userId)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to upload document: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    IdentityVerificationView()
} 
