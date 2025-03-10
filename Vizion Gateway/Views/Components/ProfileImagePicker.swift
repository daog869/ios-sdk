import SwiftUI
import PhotosUI

struct ProfileImagePicker: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isUploading = false
    @State private var uploadProgress = 0.0
    @Binding var profileImageURL: String?
    @State private var errorMessage: String?
    
    // Callback when image upload completes
    var onImageUploaded: ((String) -> Void)?
    
    // User ID for storage path
    let userId: String
    
    // Size of the profile image
    var size: CGFloat = 120
    
    // Initials to show when no image is available
    var initials: String
    
    var body: some View {
        VStack {
            ZStack {
                // Profile image or initials placeholder
                Group {
                    if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                        // Show selected image
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else if let profileURL = profileImageURL, !profileURL.isEmpty {
                        // Show existing profile image
                        AsyncImage(url: URL(string: profileURL)) { phase in
                            switch phase {
                            case .empty:
                                initialsView
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                initialsView
                            @unknown default:
                                initialsView
                            }
                        }
                    } else {
                        // Show initials
                        initialsView
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                )
                
                // Upload progress overlay
                if isUploading {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: size, height: size)
                        
                        CircularProgressView(progress: uploadProgress)
                            .frame(width: size * 0.7, height: size * 0.7)
                    }
                }
                
                // Edit button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                                .background(Circle().fill(Color.white))
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .frame(width: size, height: size)
                .padding(5)
            }
            
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let newItem = newItem {
                    await loadImageData(from: newItem)
                }
            }
        }
    }
    
    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
            
            Text(initials)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.blue)
        }
    }
    
    private func loadImageData(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                selectedImageData = data
                await uploadProfileImage()
            }
        } catch {
            errorMessage = "Failed to load image: \(error.localizedDescription)"
        }
    }
    
    private func uploadProfileImage() async {
        guard let imageData = selectedImageData else { return }
        
        isUploading = true
        uploadProgress = 0
        
        do {
            // Simulate upload progress (in a real app, you'd get this from Firebase)
            // This is for UI demonstration
            for progress in stride(from: 0.0, to: 1.0, by: 0.1) {
                try await Task.sleep(for: .milliseconds(50))
                uploadProgress = progress
            }
            
            // Upload image to Firebase
            let url = try await FirebaseManager.shared.uploadProfileImage(
                userId: userId,
                imageData: imageData,
                progressHandler: { progress in
                    uploadProgress = progress
                }
            )
            
            // Update profile image URL
            profileImageURL = url.absoluteString
            onImageUploaded?(url.absoluteString)
            
            uploadProgress = 1.0
            try await Task.sleep(for: .milliseconds(300))
        } catch {
            errorMessage = "Failed to upload: \(error.localizedDescription)"
        }
        
        isUploading = false
    }
}

// Add extension for the onImageUploaded modifier
extension ProfileImagePicker {
    func onImageUploaded(perform action: @escaping (String) -> Void) -> Self {
        var copy = self
        copy.onImageUploaded = action
        return copy
    }
}

struct CircularProgressView: View {
    var progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.gray.opacity(0.3),
                    lineWidth: 6
                )
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.blue,
                    style: StrokeStyle(
                        lineWidth: 6,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.caption.bold())
                .foregroundColor(.white)
        }
    }
}

#Preview {
    ProfileImagePicker(
        profileImageURL: .constant(nil),
        userId: "user123",
        initials: "JD"
    )
    .frame(width: 200, height: 200)
} 