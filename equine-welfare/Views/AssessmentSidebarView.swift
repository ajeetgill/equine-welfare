import SwiftData  // used in #Preview
import SwiftUI

struct AssessmentSidebarView: View {
    // Callbacks for navigation
    var onShowSectionSelection: () -> Void
    var viewModel: SectionSelectionViewModel
    var galleryViewModel: GalleryViewModel
    
    // Add NavigationPath binding for horse navigation
    @Binding var navigationPath: NavigationPath
    
    // Add current assessment ID
    var assessmentId: UUID

    @State private var isApplicableSectionsExpanded: Bool = true
    @State private var selectedSection: Section?
    @State private var currentDetailView: DetailView = .sectionSelection
    
    // Initializer with navigationPath
    init(
        onShowSectionSelection: @escaping () -> Void,
        viewModel: SectionSelectionViewModel,
        galleryViewModel: GalleryViewModel,
        navigationPath: Binding<NavigationPath> = .constant(NavigationPath()),
        assessmentId: UUID = UUID()
    ) {
        self.onShowSectionSelection = onShowSectionSelection
        self.viewModel = viewModel
        self.galleryViewModel = galleryViewModel
        self._navigationPath = navigationPath
        self.assessmentId = assessmentId
        
        print("DEBUG: AssessmentSidebarView initialized with assessmentId: \(assessmentId)")
    }
    
    // Define possible detail views
    private enum DetailView: Equatable {
        case sectionSelection
        case horses
        case gallery
        case sectionDetail(Section)
        
        static func == (lhs: DetailView, rhs: DetailView) -> Bool {
            switch (lhs, rhs) {
            case (.sectionSelection, .sectionSelection):
                return true
            case (.horses, .horses):
                return true
            case (.gallery, .gallery):
                return true
            case (.sectionDetail(let lhsSection), .sectionDetail(let rhsSection)):
                return lhsSection.id == rhsSection.id
            default:
                return false
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Navigation Actions
                navigationButtonsView
                sectionsList
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .onDisappear {
                viewModel.saveAssessment()
            }
        } detail: {
            // Show the appropriate detail view based on navigation state
            switch currentDetailView {
            case .sectionSelection:
                SectionSelectionView(viewModel: viewModel)
            case .horses:
                // Use our new wrapper view for horses navigation
                HorsesNavigationView(
                    assessmentId: assessmentId,
                    parentNavigationPath: $navigationPath
                )
                .onAppear {
                    print("DEBUG: HorsesNavigationView appeared in AssessmentSidebarView detail")
                }
            case .gallery:
                GalleryView(viewModel: galleryViewModel)
            case .sectionDetail(let section):
                SectionDetailView(section: section)
            }
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
            // Section Selection Button
            SidebarButton(
                title: "Section Selection",
                icon: "checklist",
                isActive: currentDetailView == .sectionSelection
            ) {
                selectedSection = nil
                currentDetailView = .sectionSelection
                onShowSectionSelection()
            }

            // Horses Button
            SidebarButton(
                title: "Horses",
                icon: "pawprint.fill",
                isActive: currentDetailView == .horses
            ) {
                print("DEBUG: Horses button tapped")
                selectedSection = nil
                currentDetailView = .horses
            }
            
            // Gallery Button
            SidebarButton(
                title: "Gallery",
                icon: "photo.on.rectangle",
                isActive: currentDetailView == .gallery
            ) {
                selectedSection = nil
                currentDetailView = .gallery
            }
        }
    }

    private var sectionsList: some View {
            // Keep the DisclosureGroup with dropdown functionality
            DisclosureGroup(
                isExpanded: $isApplicableSectionsExpanded,
                content: {
                    ForEach(viewModel.applicableSections) { section in
                        Button(action: {
                            selectedSection = section
                            currentDetailView = .sectionDetail(section)
                        }) {
                            HStack {
                                // Add the status indicator
                                SectionStatusIndicator(
                                    status: getSectionCompletionStatus(section)
                                )
                                .padding(.trailing, 4)
                                
                                Text("\(section.id). \(section.title)")
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(8)
                        }
                    }
                },
                label: {
                    Text("Applicable Sections")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            )
    }

    // Helper method to determine section status
    private func getSectionCompletionStatus(_ section: Section) -> SectionCompletionStatus {
        // Get all requirements for this section
        guard
            let requirements = section.subsections.flatMap({ $0.requirements })
                as? [Requirement], !requirements.isEmpty
        else {
            return .notStarted
        }

        // Count answered requirements (those with a compliance status)
        let answeredCount = requirements.filter { req in 
            req.complianceStatus != nil
        }.count

        if answeredCount == 0 {
            return .notStarted
        } else if answeredCount == requirements.count {
            return .completed
        } else {
            return .inProgress
        }
    }
}

// MARK: - Helper Views

/// Reusable sidebar button component
struct SidebarButton: View {
    let title: String
    var icon: String = "questionmark.app.dashed"
    var isActive: Bool? = false
    var onAction: (() -> Void)?

    var body: some View {
        Button(action: onAction ?? { }) {
            HStack {
                Image(systemName: icon)
                Text(title).fontWeight(isActive ?? false ? .medium : .regular)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .cornerRadius(8)
        }
    }
}

// MARK: - Section Detail View

struct SectionDetailView: View {
    let section: Section

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
                // Subsections with requirements
                ForEach(sortedSubsections, id: \.name) { subsection in
                    SubsectionView(subsection: subsection)
                }
            }
            .navigationTitle(LocalizedStringKey(section.title))
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
                TextField(
                    "Reason for non-compliance",
                    text: .init(
                        get: { requirement.nonComplianceReason ?? "" },
                        set: { requirement.nonComplianceReason = $0 }
                    )
                )
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
                                ForEach(requirement.mediaAttachments, id: \.id)
                                { attachment in
                                    MediaThumbnail(
                                        attachment: attachment, size: 80
                                    )
                                    .onTapGesture {
                                        showingMediaPreview = attachment
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            if let index = requirement
                                                .mediaAttachments.firstIndex(
                                                    where: {
                                                        $0.id == attachment.id
                                                    })
                                            {
                                                requirement.mediaAttachments
                                                    .remove(at: index)
                                            }
                                        } label: {
                                            Label(
                                                "Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    MediaPicker(isPresented: $showingMediaPicker) {
                        mediaData, mediaType in
                        let attachment =
                            mediaType == .image
                            ? MediaAttachment(imageData: mediaData)
                            : MediaAttachment(videoData: mediaData)
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
            } else {
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
                Image(
                    systemName: isSelected
                        ? "largecircle.fill.circle" : "circle")
                Text(status.rawValue)
            }
            .foregroundColor(isSelected ? .blue : .primary)
        }
    }
}

#Preview {
    // Create a simple in-memory container for the preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Assessment.self, configurations: config)

    // Create the view model with the container
    let viewModel = SectionSelectionViewModel(
        modelContext: container.mainContext)

    // Create the view with dummy callbacks
    AssessmentSidebarView(
        onShowSectionSelection: {},
        viewModel: viewModel,
        galleryViewModel: GalleryViewModel(sectionViewModel: viewModel)
    )
}
