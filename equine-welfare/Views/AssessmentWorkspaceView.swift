import SwiftData  // used in #Preview
import SwiftUI
import AVKit

/// The workspace for a single assessment: a `NavigationSplitView` whose
/// sidebar selects which pane (overview / sections / horses / gallery / notes
/// / a specific section) is shown in the detail column.
///
/// `NavigationSplitView` adapts to compact width on its own, so there is no
/// separate hand-built iPhone layout.
struct AssessmentWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var viewModel: SectionSelectionViewModel
    var galleryViewModel: GalleryViewModel
    var assessmentId: UUID

    @State private var pane: WorkspacePane? = .sections

    var body: some View {
        NavigationSplitView {
            List(selection: $pane) {
                Label("Overview", systemImage: "doc.text.magnifyingglass")
                    .tag(WorkspacePane.overview)
                Label("Section Selection", systemImage: "checklist")
                    .tag(WorkspacePane.sections)
                Label {
                    Text("Horses")
                } icon: {
                    Image("horse-icon").renderingMode(.template)
                }
                .tag(WorkspacePane.horses)
                Label("Gallery", systemImage: "photo.on.rectangle")
                    .tag(WorkspacePane.gallery)
                Label("Side Notes", systemImage: "note.text")
                    .tag(WorkspacePane.notes)

                // `Section` here is the SwiftUI container; the model type of the
                // same name shadows it (same-module wins), so qualify it.
                SwiftUI.Section("Applicable Sections") {
                    ForEach(viewModel.applicableSections) { section in
                        HStack {
                            SectionStatusIndicator(
                                status: getSectionCompletionStatus(section),
                                isSelected: pane == .section(id: section.id)
                            )
                            .padding(.trailing, 4)

                            Text("\(section.id). \(section.title)")
                        }
                        .tag(WorkspacePane.section(id: section.id))
                    }
                }
            }
            .navigationTitle("Assessment")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        viewModel.saveAssessment()
                        dismiss()
                    }
                }
            }
        } detail: {
            detailContent
        }
        .onDisappear {
            viewModel.saveAssessment()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch pane {
        case .overview:
            if let assessment = viewModel.assessment {
                AssessmentOverviewView(
                    assessment: assessment,
                    modelContext: modelContext
                )
            }
        case .sections, .none:
            SectionSelectionView(viewModel: viewModel)
        case .horses:
            HorsesPaneView(assessmentId: assessmentId)
        case .gallery:
            GalleryView(viewModel: galleryViewModel)
        case .notes:
            if let assessment = viewModel.currentAssessment {
                SideNotesView(assessment: assessment)
            }
        case .section(let id):
            if let section = viewModel.applicableSections.first(where: { $0.id == id }) {
                SectionDetailView(section: section)
            } else {
                Text("Section not found")
            }
        }
    }

    // Helper method to determine section status
    private func getSectionCompletionStatus(_ section: Section)
        -> SectionCompletionStatus
    {
        // Get all requirements for this section
        let requirements = section.subsections.flatMap { $0.requirements }
        guard !requirements.isEmpty else {
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
        .background(Color(.secondarySystemGroupedBackground))
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
            let asset = AVURLAsset(url: tempURL)

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

    // Create the view with dummy dependencies
    AssessmentWorkspaceView(
        viewModel: viewModel,
        galleryViewModel: GalleryViewModel(sectionViewModel: viewModel),
        assessmentId: UUID()
    )
}
