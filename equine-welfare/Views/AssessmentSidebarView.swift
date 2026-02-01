import SwiftData  // used in #Preview
import SwiftUI
import AVKit

struct AssessmentSidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
    }
    
    // Update DetailView enum
    private enum DetailView: Equatable {
        case overview
        case sectionSelection
        case horses
        case gallery
        case sideNotes
        case sectionDetail(Section)

        static func == (lhs: DetailView, rhs: DetailView) -> Bool {
            switch (lhs, rhs) {
            case (.overview, .overview): return true
            case (.sectionSelection, .sectionSelection): return true
            case (.horses, .horses): return true
            case (.gallery, .gallery): return true
            case (.sideNotes, .sideNotes): return true
            case (.sectionDetail(let lhs), .sectionDetail(let rhs)):
                return lhs.id == rhs.id
            default: return false
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch currentDetailView {
        case .overview:
            if let assessment = viewModel.assessment {
                AssessmentOverviewView(
                    assessment: assessment,
                    modelContext: modelContext
                )
            }
        case .sectionSelection:
            SectionSelectionView(viewModel: viewModel)
        case .horses:
            HorsesNavigationView(
                assessmentId: assessmentId
            )
        case .gallery:
            GalleryView(viewModel: galleryViewModel)
        case .sideNotes:
            if let assessment = viewModel.currentAssessment {
                SideNotesView(assessment: assessment)
            }
        case .sectionDetail(let section):
            SectionDetailView(section: section)
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 0) {
            // Navigation picker at the top
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CompactNavButton(title: "Overview", icon: "doc.text.magnifyingglass",
                                     isActive: currentDetailView == .overview) {
                        selectedSection = nil
                        currentDetailView = .overview
                    }
                    CompactNavButton(title: "Sections", icon: "checklist",
                                     isActive: currentDetailView == .sectionSelection) {
                        selectedSection = nil
                        currentDetailView = .sectionSelection
                    }
                    CompactNavButton(title: "Horses", icon: "pawprint.fill",
                                     isActive: currentDetailView == .horses) {
                        selectedSection = nil
                        currentDetailView = .horses
                    }
                    CompactNavButton(title: "Gallery", icon: "photo.on.rectangle",
                                     isActive: currentDetailView == .gallery) {
                        selectedSection = nil
                        currentDetailView = .gallery
                    }
                    CompactNavButton(title: "Notes", icon: "note.text",
                                     isActive: currentDetailView == .sideNotes) {
                        selectedSection = nil
                        currentDetailView = .sideNotes
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))

            Divider()

            // Detail content
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onDisappear {
            viewModel.saveAssessment()
        }
    }

    var body: some View {
        if horizontalSizeClass == .compact {
            compactLayout
        } else {
            NavigationSplitView {
                ScrollView {
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
                detailContent
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
            // Overview Button
            SidebarButton(
                title: "Overview",
                icon: "doc.text.magnifyingglass",
                isActive: currentDetailView == .overview
            )
             {
                selectedSection = nil
                currentDetailView = .overview
            }
            
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
                customImage: "horse-icon",
                isActive: currentDetailView == .horses
            ) {
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
            
            // Side Notes Button
            SidebarButton(
                title: "Side Notes",
                icon: "note.text",
                isActive: currentDetailView == .sideNotes
            ) {
                selectedSection = nil
                currentDetailView = .sideNotes
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
                                status: getSectionCompletionStatus(section),
                                isSelected: selectedSection?.id == section.id
                            )
                            .padding(.trailing, 4)

                            Text("\(section.id). \(section.title)")
                                .foregroundColor(selectedSection?.id == section.id ? .white : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .background(selectedSection?.id == section.id ? Color.accentColor : Color.clear)
                        .cornerRadius(8)
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
    private func getSectionCompletionStatus(_ section: Section)
        -> SectionCompletionStatus
    {
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
    var customImage: String?
    var isActive: Bool? = false
    var onAction: (() -> Void)?

    var body: some View {
        Button(action: onAction ?? { }) {
            HStack {
                if let img = customImage {
                    Image(img)
                        .renderingMode(.template)
                        .foregroundColor(isActive ?? false ? .white : .accentColor)
                }
                else {
                    Image(systemName: icon)
                        .foregroundColor(isActive ?? false ? .white : .accentColor)
                }
                Text(title)
                    .fontWeight(isActive ?? false ? .medium : .regular)
                    .foregroundColor(isActive ?? false ? .white : .accentColor)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isActive ?? false ? Color.accentColor : Color.clear)
            .cornerRadius(8)
        }
    }
}

/// Compact navigation button for iPhone layout
struct CompactNavButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isActive ? .white : .accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.accentColor : Color(.systemGray6))
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
                                    .frame(width: 100, height: 100)
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
//                                    .overlay(
//                                        Button(action: {
//                                            if let index = requirement
//                                                .mediaAttachments.firstIndex(
//                                                    where: {
//                                                        $0.id == attachment.id
//                                                    })
//                                            {
//                                                requirement.mediaAttachments
//                                                    .remove(at: index)
//                                            }
//                                        }) {
//                                            Image(systemName: "xmark.circle.fill")
//                                                .foregroundColor(.white)
//                                                .background(Color.black.opacity(0.7))
//                                                .clipShape(Circle())
//                                        }
//                                        .padding(4)
//                                        ,alignment: .topTrailing
//                                    )
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
    @State private var videoPlayer: AVPlayer?
    @State private var tempVideoURL: URL?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if attachment.mediaType == .image {
                    if let uiImage = UIImage(data: attachment.data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                } else if attachment.mediaType == .video {
                    videoPlayerView
                } else {
                    Text("Unsupported media type")
                }
            }
            .padding()
            .navigationTitle(attachment.mediaType == .video ? "Video Preview" : "Image Preview")
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
    
    private var videoPlayerView: some View {
        Group {
            if let player = videoPlayer {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fit)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: 300)
            }
        }
    }
    
    private func prepareVideoPlayer() {
        guard attachment.mediaType == .video else { return }
        
        // Create a temporary file to play the video
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent("temp_video_\(UUID().uuidString).mp4")
        self.tempVideoURL = tempURL
        
        do {
            try attachment.data.write(to: tempURL)
            
            // Create asset and check if it's playable
            let asset = AVAsset(url: tempURL)
            
            Task {
                do {
                    // Check if the asset is playable
                    let playable = try await asset.load(.isPlayable)
                    if playable {
                        DispatchQueue.main.async {
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
                        DispatchQueue.main.async {
                            self.showError = true
                            self.errorMessage = "This video format is not supported"
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
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
