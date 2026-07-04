import SwiftUI
import AVFoundation

struct MediaThumbnail: View {
    let attachment: MediaAttachment
    let size: CGFloat
    @State private var videoThumbnail: UIImage?
    
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
        else if attachment.mediaType == .video {
            ZStack {
                if let thumbnail = videoThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Color(.systemGray5)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Image(systemName: "video.fill")
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .foregroundColor(.gray)
                        .frame(width: size * 0.6, height: size * 0.6)
                }
                
                // Play button overlay
                Image(systemName: "play.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.white)
                    .frame(width: size * 0.3)
                    .shadow(radius: 2)
            }
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .onAppear {
                generateVideoThumbnail()
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
    
    private func generateVideoThumbnail() {
        guard attachment.mediaType == .video, videoThumbnail == nil else { return }
        
        // Create a temporary file to process the video
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent("temp_thumbnail_\(UUID().uuidString).mp4")
        
        do {
            try attachment.data.write(to: tempURL)
            
            // Create an asset and get thumbnail
            let asset = AVURLAsset(url: tempURL)
            
            Task {
                do {
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = CGSize(width: size * 2, height: size * 2) // 2x size for higher quality
                    
                    // Try to get thumbnail at 1 second or at the start
                    let seconds = try await asset.load(.duration).seconds > 1.0 ? 1.0 : 0.0
                    let time = CMTime(seconds: seconds, preferredTimescale: 60)
                    
                    let (cgImage, _) = try await generator.image(at: time)
                    let thumbnail = UIImage(cgImage: cgImage)

                    await MainActor.run {
                        self.videoThumbnail = thumbnail
                    }

                    // Clean up the temp file
                    try? FileManager.default.removeItem(at: tempURL)
                } catch {
                    print("Error generating thumbnail: \(error)")
                    try? FileManager.default.removeItem(at: tempURL)
                }
            }
        } catch {
            print("Error writing video file for thumbnail: \(error)")
        }
    }
}

#Preview {
    let imageData = UIImage(systemName: "photo")?.jpegData(compressionQuality: 1.0) ?? Data()
    let imageAttachment = MediaAttachment(imageData: imageData)
    
    return VStack(spacing: 20) {
        MediaThumbnail(attachment: imageAttachment, size: 80)
        
        // Add video preview
        MediaThumbnail(attachment: MediaAttachment(videoData: Data()), size: 80)
    }
} 
