import MijickCamera
import PhotosUI
import SwiftUI

struct MediaPicker: View {
    @Binding var isPresented: Bool
    var onMediaSelected: (Data, MediaType) -> Void
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCameraSheet: Bool = false

    var body: some View {
        HStack {
            Button(action: {
                isPresented = true
            }) {
                Label("Add Photo", systemImage: "photo")
            }
            .buttonStyle(.bordered)
            .photosPicker(
                isPresented: $isPresented, selection: $selectedItem,
                matching: .images
            )
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(
                        type: Data.self)
                    {
                        onMediaSelected(data, .image)
                    }
                }
            }
            Button(action: {
                showCameraSheet = true
            }) {
                Image(systemName: "camera")
            }
            .buttonStyle(.bordered)
            .fullScreenCover(isPresented: $showCameraSheet) {
                MCamera()
                    .onImageCaptured { image, controller in
                        saveImageInGallery(image)
                        showCameraSheet = false
                        //                                    controller.reopenCameraScreen()
                    }
                    .onVideoCaptured { videoURL, controller in
                        saveVideoInGallery(videoURL)
                        showCameraSheet = false
                        //                                    controller.reopenCameraScreen()
                    }
                    .setCloseMCameraAction {
                        print("Camera closed")
                        showCameraSheet = false
                    }
                    .startSession()
            }
        }
    }

    private func saveImageInGallery(_ image: UIImage) {
        print("saveImageInGallery")
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            onMediaSelected(imageData, .image)
        }
    }
    private func saveVideoInGallery(_ videoURL: URL) {
        print("saveVideoInGallery")

        do {
            // Read the video file data - be careful with large videos!
            let videoData = try Data(contentsOf: videoURL)
            onMediaSelected(videoData, .video)
        } catch {
            print("Error loading video data: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var isPresented = false

    MediaPicker(
        isPresented: $isPresented,
        onMediaSelected: { data, type in
            print("Image selected with \(data.count) bytes of type:\(type)")
        }
    )
}
