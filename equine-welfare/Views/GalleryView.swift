import SwiftUI

struct GalleryView: View {
    @ObservedObject var viewModel: GalleryViewModel
    @State private var selectedImage: GalleryImage?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Assessment Gallery")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)
            
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
                            GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let uiImage = UIImage(data: image.attachment.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .frame(height: 120)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Text(image.subsectionName)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

struct ImageDetailView: View {
    let image: GalleryImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let uiImage = UIImage(data: image.attachment.imageData) {
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
            .navigationTitle("Image Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

//#Preview {
//    let viewModel = GalleryViewModel(sectionViewModel: SectionSelectionViewModel(modelContext: ModelContext(try! ModelContainer(for: Assessment.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))))
//    
//    return GalleryView(viewModel: viewModel)
//} 
