import SwiftUI

struct MediaThumbnail: View {
    let attachment: MediaAttachment
    let size: CGFloat
    
    var body: some View {
        if attachment.mediaType == .image {
            if let uiImage = UIImage(data: attachment.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        else {
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .padding()
                .foregroundColor(.gray)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

#Preview {
    let imageData = UIImage(systemName: "photo")?.jpegData(compressionQuality: 1.0) ?? Data()
    let attachment = MediaAttachment(imageData: imageData)
    
    return MediaThumbnail(attachment: attachment, size: 80)
} 
