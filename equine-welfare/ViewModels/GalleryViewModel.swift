import SwiftUI
import SwiftData

class GalleryViewModel: ObservableObject {
    @Published var galleryItems: [GallerySection] = []
    
    private let sectionViewModel: SectionSelectionViewModel
    
    init(sectionViewModel: SectionSelectionViewModel) {
        self.sectionViewModel = sectionViewModel
        refreshGallery()
    }
    
    func refreshGallery() {
        var newGalleryItems: [GallerySection] = []
        
        // Only include applicable sections
        for section in sectionViewModel.applicableSections {
            var sectionImages: [GalleryImage] = []
            
            for subsection in section.subsections {
                for requirement in subsection.requirements {
                    if requirement.complianceStatus == .notCompliant && !requirement.mediaAttachments.isEmpty {
                        for attachment in requirement.mediaAttachments {
                            let galleryImage = GalleryImage(
                                id: attachment.id,
                                attachment: attachment,
                                requirementText: requirement.text,
                                subsectionName: subsection.name
                            )
                            sectionImages.append(galleryImage)
                        }
                    }
                }
            }
            
            if !sectionImages.isEmpty {
                let gallerySection = GallerySection(
                    id: section.id,
                    title: section.title,
                    images: sectionImages
                )
                newGalleryItems.append(gallerySection)
            }
        }
        
        galleryItems = newGalleryItems
    }
}

// Data structures for the gallery
struct GallerySection: Identifiable {
    let id: Int
    let title: String
    let images: [GalleryImage]
}

struct GalleryImage: Identifiable {
    let id: UUID
    let attachment: MediaAttachment
    let requirementText: String
    let subsectionName: String
} 