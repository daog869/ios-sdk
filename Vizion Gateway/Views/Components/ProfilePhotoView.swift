import SwiftUI

struct ProfilePhotoView: View {
    let imageURL: String?
    let initials: String
    var size: CGFloat = 40
    var showBorder: Bool = true
    
    var body: some View {
        if let imageURL = imageURL, !imageURL.isEmpty {
            // Display profile image
            AsyncImage(url: URL(string: imageURL)) { phase in
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
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: showBorder ? 1 : 0)
            )
        } else {
            // Display initials
            initialsView
        }
    }
    
    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: size, height: size)
            
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.blue)
        }
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: showBorder ? 1 : 0)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfilePhotoView(imageURL: nil, initials: "AB", size: 120)
        
        HStack(spacing: 20) {
            ProfilePhotoView(imageURL: nil, initials: "CD", size: 60)
            ProfilePhotoView(imageURL: nil, initials: "EF", size: 40)
            ProfilePhotoView(imageURL: nil, initials: "GH", size: 32)
        }
    }
    .padding()
} 