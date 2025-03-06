import SwiftUI
import PhotosUI

struct MediaPicker: View {
    @Binding var isPresented: Bool
    var onImageSelected: (Data) -> Void
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        Button(action: {
            isPresented = true
        }) {
            Label("Add Photo", systemImage: "photo")
        }
        .buttonStyle(.bordered)
        .photosPicker(isPresented: $isPresented, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    onImageSelected(data)
                }
            }
        }
    }
} 