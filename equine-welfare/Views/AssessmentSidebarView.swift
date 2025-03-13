import SwiftUI

struct AssessmentSidebarView: View {
    @ObservedObject var viewModel: SectionSelectionViewModel
    @State private var isApplicableSectionsExpanded: Bool = true
    @EnvironmentObject private var navigationState: NavigationState
    @StateObject private var galleryViewModel: GalleryViewModel
    
    init(viewModel: SectionSelectionViewModel) {
        self.viewModel = viewModel
        self._galleryViewModel = StateObject(wrappedValue: GalleryViewModel(sectionViewModel: viewModel))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MARK: - Header
            headerView
            
            // MARK: - Navigation Actions
            navigationButtonsView
            
            // MARK: - Applicable Sections
            sectionsList
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .onDisappear {
            viewModel.saveAssessment()
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            Text("Assessment")
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
        }
    }
    
    private var navigationButtonsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Back to Home Button
            SidebarButton(
                title: "Back to Home",
                icon: "chevron.left",
                isActive: false,
                action: {
                    viewModel.prepareForReturn {
                        navigationState.returnToMain()
                    }
                }
            )
            
            // Section Selection Button
            SidebarButton(
                title: "Section Selection",
                icon: "checklist",
                isActive: navigationState.selectedSectionId == nil && !isHorsesScreen() && !isHorseDetailScreen() && !isHorseInfoScreen() && !navigationState.showingGallery,
                action: {
                    navigationState.showSectionSelection()
                }
            )
            
            // Horses Button
            SidebarButton(
                title: "Horses",
                icon: "pawprint.fill",
                isActive: isHorsesScreen(),
                action: {
                    navigationState.showHorses()
                }
            )
            // Gallery Button
            SidebarButton(
                title: "Gallery",
                icon: "photo.on.rectangle",
                isActive: navigationState.showingGallery,
                action: {
                    galleryViewModel.refreshGallery()
                    navigationState.showGallery()
                }
            )
        }
    }
    
    private var sectionsList: some View {
        DisclosureGroup(
            isExpanded: $isApplicableSectionsExpanded,
            content: {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.applicableSections, id: \.id) { section in
                        SidebarButton(
                            title: "\(section.id). \(section.title)",
                            isActive: navigationState.selectedSectionId == section.id && !navigationState.showingGallery,
                            isPrimary: false,
                            action: {
                                navigationState.navigateToSection(sectionId: section.id)
                                navigationState.selectedSectionId = section.id
                            }
                        )
                    }
                }
                .padding(.top, 4)
            },
            label: {
                Text("Applicable Sections")
                    .fontWeight(.medium)
            }
        )
    }
    
    private func isHorsesScreen() -> Bool {
        if case .horses = navigationState.currentScreen {
            return true
        }
        return false
    }
    
    private func isHorseDetailScreen() -> Bool {
        if case .horseDetail = navigationState.currentScreen {
            return true
        }
        return false
    }
    
    private func isHorseInfoScreen() -> Bool {
        if case .horseInfo = navigationState.currentScreen {
            return true
        }
        return false
    }
}

// MARK: - Helper Views

/// Reusable sidebar button component
struct SidebarButton: View {
    let title: String
    var icon: String? = nil
    var isActive: Bool = false
    var isPrimary: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let iconName = icon {
                    Image(systemName: iconName)
                }
                
                Text(title)
                    .fontWeight(isPrimary ? .medium : .regular)
                
                Spacer()
            }
            .padding(isPrimary ? 12 : 8)
            .padding(.leading, isPrimary ? 0 : 16)
            .background(isActive ? Color.blue : (isPrimary ? Color.blue.opacity(0.1) : Color.clear))
            .foregroundColor(isActive ? .white : (isPrimary ? .blue : .primary))
            .cornerRadius(8)
        }
    }
}

// MARK: - Section Detail View

struct SectionDetailView: View {
    let section: Section
    @EnvironmentObject private var navigationState: NavigationState
    
    private var sortedSubsections: [Subsection] {
        section.subsections.sorted { s1, s2 in
            let comps1 = s1.name.numericComponents()
            let comps2 = s2.name.numericComponents()
            
            // Compare components lexicographically
            for i in 0..<min(comps1.count, comps2.count) {
                if comps1[i] < comps2[i] { return true }
                if comps1[i] > comps2[i] { return false }
            }
            // If all common components match, shorter array comes first
            return comps1.count < comps2.count
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section header
                Text(section.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 20)
                
                // Subsections with requirements
                ForEach(sortedSubsections, id: \.name) { subsection in
                    SubsectionView(subsection: subsection)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(.systemGray6))
    }
}

struct SubsectionView: View {
    let subsection: Subsection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(subsection.name)
                .font(.title2)
                .fontWeight(.semibold)
            
            ForEach(subsection.requirements, id: \.text) { requirement in
                RequirementView(requirement: requirement)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
    }
}

struct RequirementView: View {
    let requirement: Requirement
    @State private var showingMediaPicker = false
    @State private var showingMediaPreview: MediaAttachment?
    
    private var selectableStatuses: [ComplianceStatus] {
        [.compliant, .notCompliant, .notApplicable]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(requirement.text)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 16) {
                ForEach(selectableStatuses, id: \.self) { status in
                    ComplianceButton(
                        status: status,
                        isSelected: requirement.complianceStatus == status,
                        action: {
                            requirement.complianceStatus = status
                            if status == .notCompliant {
                                requirement.nonComplianceReason = ""
                            } else {
                                requirement.nonComplianceReason = nil
                                // Clear media attachments when not non-compliant
                                requirement.mediaAttachments.removeAll()
                            }
                        }
                    )
                }
            }
            
            if requirement.complianceStatus == .notCompliant {
                TextField("Reason for non-compliance", text: .init(
                    get: { requirement.nonComplianceReason ?? "" },
                    set: { requirement.nonComplianceReason = $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.top, 4)
                
                // Media attachments section
                VStack(alignment: .leading, spacing: 8) {
                    if !requirement.mediaAttachments.isEmpty {
                        Text("Evidence:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(requirement.mediaAttachments, id: \.id) { attachment in
                                    MediaThumbnail(attachment: attachment, size: 80)
                                        .onTapGesture {
                                            showingMediaPreview = attachment
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                if let index = requirement.mediaAttachments.firstIndex(where: { $0.id == attachment.id }) {
                                                    requirement.mediaAttachments.remove(at: index)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    MediaPicker(isPresented: $showingMediaPicker) { mediaData, mediaType  in
                        let attachment = mediaType == .image ?  MediaAttachment(imageData: mediaData) :
                        MediaAttachment(videoData: mediaData)
                        requirement.mediaAttachments.append(attachment)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
        .sheet(item: $showingMediaPreview) { attachment in
            MediaPreviewView(attachment: attachment)
        }
    }
}

struct MediaPreviewView: View {
    let attachment: MediaAttachment
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            if attachment.mediaType == .image {
                if let uiImage = UIImage(data: attachment.data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
            }
            else{
                Text("Unsupported media type")
            }
            
        }
            .navigationTitle("Image Preview")
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

struct ComplianceButton: View {
    let status: ComplianceStatus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                Text(status.rawValue)
            }
            .foregroundColor(isSelected ? .blue : .primary)
        }
    }
}
