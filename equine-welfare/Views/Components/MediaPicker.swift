import MijickCamera
import PhotosUI
import SwiftUI
import AVFoundation

struct MediaPicker: View {
    @Binding var isPresented: Bool
    var cameraOnly: Bool = false
    var galleryOnly: Bool = false
    var cameraText: String = "Camera"
    var galleryText: String = "Gallery"
    var onMediaSelected: (Data, MediaType) -> Void

    var body: some View {
        HStack {
            if(!cameraOnly && !galleryOnly){
                GalleryButton(galleryText: galleryText, isPresented: $isPresented, onMediaSelected: onMediaSelected)
                CameraButton(cameraText: cameraText, onMediaSelected: onMediaSelected)
            } else if(cameraOnly && !galleryOnly){
                CameraButton(cameraText: cameraText, onMediaSelected: onMediaSelected)
            }else if(galleryOnly && !cameraOnly){
                GalleryButton(galleryText: galleryText, isPresented: $isPresented, onMediaSelected: onMediaSelected)
            }
        }
    }
}

struct GalleryButton: View {
    var galleryText: String = ""
    @Binding var isPresented: Bool
    @State private var selectedItem: PhotosPickerItem?
    var onMediaSelected: (Data, MediaType) -> Void
    
    var body: some View {
        Button(action: {
            isPresented = true
        }) {
            if galleryText != "" {
                Label(galleryText, systemImage: "photo")
            }else{
                Image(systemName: "photo")
            }
        }
        .buttonStyle(.bordered)
        .photosPicker(
            isPresented: $isPresented, selection: $selectedItem
        )
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    // Convert to JPEG format with 0.8 compression quality
                    if let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
                        onMediaSelected(jpegData, .image)
                    }
                }
            }
        }
    }
}

struct CameraButton: View{
    var cameraText: String = ""
    @State private var showCameraSheet: Bool = false
    var onMediaSelected: (Data, MediaType) -> Void
    
    var body: some View {
        Button(action: {
            showCameraSheet = true
        }) {
            if cameraText != "" {
                Label(cameraText, systemImage: "camera")
            }else{
                Image(systemName: "camera")
            }
        }
        .buttonStyle(.bordered)
        .fullScreenCover(isPresented: $showCameraSheet) {
            MCamera()
                .setCameraScreen(CustomCameraScreen.init)
                .onImageCaptured { image, _ in
                    saveImageInGallery(image)
                    showCameraSheet = false
                }
                .onVideoCaptured { videoURL, _ in
                    Task {
                        await convertAndSaveVideo(videoURL)
                    }
                    showCameraSheet = false
                }
                .setCloseMCameraAction {
                    print("Camera closed")
                    showCameraSheet = false
                }
                .startSession()
        }
    }
    
    func saveImageInGallery(_ image: UIImage) {
        print("saveImageInGallery")
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            onMediaSelected(imageData, .image)
        }
    }

    func convertAndSaveVideo(_ sourceURL: URL) async {
        print("Converting and saving video")
        
        do {
            let asset = AVURLAsset(url: sourceURL)
            
            // Create a temporary file URL for the exported video
            let tempDir = FileManager.default.temporaryDirectory
            let outputURL = tempDir.appendingPathComponent("converted_video_\(UUID().uuidString).mp4")
            
            // Configure export session
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
                print("Failed to create export session")
                return
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.shouldOptimizeForNetworkUse = true
            
            // Export the video
            await exportSession.export()
            
            // Check export status
            if exportSession.status == .completed {
                // Read the converted video data
                let videoData = try Data(contentsOf: outputURL)
                onMediaSelected(videoData, .video)
                
                // Clean up temporary file
                try? FileManager.default.removeItem(at: outputURL)
            } else if let error = exportSession.error {
                print("Video conversion failed: \(error.localizedDescription)")
            }
        } catch {
            print("Error processing video: \(error.localizedDescription)")
        }
    }
    
}
// MARK: - Preview
#Preview {
    @Previewable @State var isPresented = false

    MediaPicker(
        isPresented: $isPresented,
        onMediaSelected: { data, type in
            print("Media selected with \(data.count) bytes of type:\(type)")
        }
    )
}
