import SwiftUI
import PhotosUI

struct FileUploaderView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var uploadedImageURL: URL?
    @State private var isUploading = false
    @State private var uploadProgress = 0.0
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("File Upload Example")
                .font(.headline)
            
            // Display selected or uploaded image
            if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 3)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            // Upload progress
            if isUploading {
                ProgressView(value: uploadProgress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal)
                
                Text("\(Int(uploadProgress * 100))% Uploaded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
            
            // URL of uploaded file
            if let uploadedImageURL = uploadedImageURL {
                Text("File URL:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(uploadedImageURL.absoluteString)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal)
            }
            
            // Action buttons
            HStack(spacing: 20) {
                // Image picker
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Select Image", systemImage: "photo")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isUploading)
                
                // Upload button
                Button(action: uploadImage) {
                    Label("Upload", systemImage: "arrow.up.to.line")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(selectedImageData == nil || isUploading)
            }
        }
        .padding()
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                    uploadedImageURL = nil
                    errorMessage = nil
                }
            }
        }
    }
    
    private func uploadImage() {
        guard let imageData = selectedImageData else { return }
        
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        // Create a unique filename
        let filename = "images/\(UUID().uuidString).jpg"
        
        // Upload the image
        Task {
            do {
                // Simulate upload progress
                for progress in stride(from: 0.0, to: 1.0, by: 0.1) {
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                    uploadProgress = progress
                }
                
                // Actual upload to Firebase Storage
                let url = try await FirebaseManager.shared.uploadFile(
                    data: imageData,
                    path: filename,
                    metadata: ["contentType": "image/jpeg"]
                )
                
                // Update UI on the main thread
                DispatchQueue.main.async {
                    uploadProgress = 1.0
                    uploadedImageURL = url
                    isUploading = false
                }
                
                // Simulate completion delay
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
                
            } catch {
                // Handle upload error
                DispatchQueue.main.async {
                    errorMessage = "Upload failed: \(error.localizedDescription)"
                    isUploading = false
                }
            }
        }
    }
}

// MARK: - File Download Example

struct FileDownloaderView: View {
    @State private var fileURL: String = ""
    @State private var downloadedData: Data?
    @State private var isDownloading = false
    @State private var downloadProgress = 0.0
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("File Download Example")
                .font(.headline)
            
            // File path input
            TextField("Enter file path (e.g. images/file.jpg)", text: $fileURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            // Display downloaded image if it's an image
            if let data = downloadedData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 3)
            } else if downloadedData != nil {
                Text("Downloaded \(downloadedData?.count ?? 0) bytes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "arrow.down.doc")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            // Download progress
            if isDownloading {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal)
                
                Text("\(Int(downloadProgress * 100))% Downloaded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
            
            // Download button
            Button(action: downloadFile) {
                Label("Download", systemImage: "arrow.down.to.line")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(fileURL.isEmpty || isDownloading)
        }
        .padding()
    }
    
    private func downloadFile() {
        guard !fileURL.isEmpty else { return }
        
        isDownloading = true
        downloadProgress = 0.0
        errorMessage = nil
        downloadedData = nil
        
        Task {
            do {
                // Simulate download progress
                for progress in stride(from: 0.0, to: 1.0, by: 0.1) {
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                    downloadProgress = progress
                }
                
                // Actual download from Firebase Storage
                let data = try await FirebaseManager.shared.downloadFile(path: fileURL)
                
                // Update UI on the main thread
                DispatchQueue.main.async {
                    downloadProgress = 1.0
                    downloadedData = data
                    isDownloading = false
                }
                
            } catch {
                // Handle download error
                DispatchQueue.main.async {
                    errorMessage = "Download failed: \(error.localizedDescription)"
                    isDownloading = false
                }
            }
        }
    }
}

// MARK: - Combined File Operations Demo

struct FileOperationsView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            Picker("Operation", selection: $selectedTab) {
                Text("Upload").tag(0)
                Text("Download").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if selectedTab == 0 {
                FileUploaderView()
            } else {
                FileDownloaderView()
            }
        }
        .navigationTitle("File Operations")
    }
}

#Preview {
    NavigationStack {
        FileOperationsView()
    }
} 