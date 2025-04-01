import SwiftUI
import AVKit

struct MediaViewer: View {
    let attachment: MediaAttachment
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.9)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }
                
                Group {
                    if attachment.mediaType == .image,
                       let uiImage = UIImage(data: attachment.data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: geometry.size.width * 0.9,
                                   maxHeight: geometry.size.height * 0.9)
                    } else if attachment.mediaType == .video {
                        VideoPlayer(player: player)
                            .frame(maxWidth: geometry.size.width * 0.9,
                                   maxHeight: geometry.size.height * 0.9)
                            .onAppear {
                                setupVideoPlayer()
                            }
                            .onDisappear {
                                player?.pause()
                                player = nil
                            }
                    }
                }
                .cornerRadius(12)
            }
        }
    }
    
    private func setupVideoPlayer() {
        // Create a temporary file to play the video
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent("temp_video_\(UUID().uuidString).mp4")
        
        do {
            try attachment.data.write(to: tempURL)
            player = AVPlayer(url: tempURL)
            player?.play()
            
            // Clean up temp file when done
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main) { _ in
                    try? FileManager.default.removeItem(at: tempURL)
                }
        } catch {
            print("Error setting up video player: \(error)")
        }
    }
}

#Preview {
    MediaViewer(attachment: MediaAttachment(imageData: UIImage(systemName: "photo")?.jpegData(compressionQuality: 1.0) ?? Data()))
}