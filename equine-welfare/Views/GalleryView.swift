import SwiftUI
import AVKit

struct GalleryView: View {
    var viewModel: GalleryViewModel
    @State private var selectedImage: GalleryImage?
    
    var body: some View {
        VStack(alignment: .leading) {
            if viewModel.galleryItems.isEmpty {
                emptyGalleryView
            } else {
                galleryContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemGray6))
        .onAppear {
            viewModel.refreshGallery()
        }
        .sheet(item: $selectedImage) { image in
            ImageDetailView(image: image)
        }
        .navigationTitle(LocalizedStringKey("Assessment Sections Gallery"))
    }
    
    private var emptyGalleryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No images available")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("Images from non-compliant requirements will appear here")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var galleryContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(viewModel.galleryItems) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Section \(section.id): \(section.title)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 180, maximum: 180), spacing: 16)
                        ], spacing: 16) {
                            ForEach(section.images) { image in
                                GalleryImageView(image: image)
                                    .onTapGesture {
                                        selectedImage = image
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom)
        }
    }
}

struct GalleryImageView: View {
    let image: GalleryImage
    @State private var videoThumbnail: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if image.attachment.mediaType == .image {
                if let uiImage = UIImage(data: image.attachment.data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            else if image.attachment.mediaType == .video {
                ZStack {
                    if let thumbnail = videoThumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 180, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Color(.systemGray5)
                            .frame(width: 180, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Play button overlay
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                        .frame(width: 40)
                        .shadow(radius: 2)
                }
                .onAppear {
                    generateVideoThumbnail()
                }
            }
            else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .frame(width: 180, height: 120)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Text(image.subsectionName)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    private func generateVideoThumbnail() {
        guard image.attachment.mediaType == .video, videoThumbnail == nil else { return }
        
        // Create a temporary file to process the video
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent("temp_thumbnail_\(UUID().uuidString).mp4")
        
        do {
            try image.attachment.data.write(to: tempURL)
            
            // Create an asset and get thumbnail
            let asset = AVURLAsset(url: tempURL)

            Task {
                do {
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = CGSize(width: 360, height: 240) // 2x size for higher quality

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

struct ImageDetailView: View {
    let image: GalleryImage
    @Environment(\.dismiss) private var dismiss
    @State private var videoPlayer: AVPlayer?
    @State private var tempVideoURL: URL?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if image.attachment.mediaType == .image {
                        if let uiImage = UIImage(data: image.attachment.data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    } else if image.attachment.mediaType == .video {
                        if let player = videoPlayer {
                            VideoPlayer(player: player)
                                .aspectRatio(contentMode: .fit)
                                .frame(minHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onAppear {
                                    player.play()
                                }
                                .onDisappear {
                                    player.pause()
                                }
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Subsection:")
                            .font(.headline)
                        Text(image.subsectionName)
                            .padding(.bottom, 4)
                        
                        Text("Requirement:")
                            .font(.headline)
                        Text(image.requirementText)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle(image.attachment.mediaType == .video ? "Video Details" : "Image Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        cleanupResources()
                        dismiss()
                    }
                }
            }
            .onAppear {
                prepareVideoPlayer()
            }
            .onDisappear {
                cleanupResources()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func prepareVideoPlayer() {
        guard image.attachment.mediaType == .video else { return }
        
        // Create a temporary file to play the video
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent("temp_video_\(UUID().uuidString).mp4")
        self.tempVideoURL = tempURL
        
        do {
            try image.attachment.data.write(to: tempURL)
            
            // Create asset and check if it's playable
            let asset = AVURLAsset(url: tempURL)
            
            Task {
                do {
                    // Check if the asset is playable
                    let playable = try await asset.load(.isPlayable)
                    if playable {
                        await MainActor.run {
                            self.videoPlayer = AVPlayer(url: tempURL)
                            // Add observer for item status
                            NotificationCenter.default.addObserver(
                                forName: .AVPlayerItemFailedToPlayToEndTime,
                                object: self.videoPlayer?.currentItem,
                                queue: .main) { _ in
                                    self.showError = true
                                    self.errorMessage = "Failed to play video"
                                }
                        }
                    } else {
                        await MainActor.run {
                            self.showError = true
                            self.errorMessage = "This video format is not supported"
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.showError = true
                        self.errorMessage = "Error loading video: \(error.localizedDescription)"
                    }
                }
            }
        } catch {
            self.showError = true
            self.errorMessage = "Error creating video file: \(error.localizedDescription)"
        }
    }
    
    private func cleanupResources() {
        // Stop and release player
        videoPlayer?.pause()
        videoPlayer = nil
        
        // Clean up temporary file
        if let tempURL = tempVideoURL {
            try? FileManager.default.removeItem(at: tempURL)
            self.tempVideoURL = nil
        }
        
        // Remove any observers
        NotificationCenter.default.removeObserver(self)
    }
}
