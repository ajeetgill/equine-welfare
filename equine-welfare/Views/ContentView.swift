import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var assessments: [Assessment]

    @State private var vetName = ""
    @State private var farmName = ""
    @State private var visitDate = Date()
    @State private var openAssessment: OpenAssessment?
    @State private var sectionViewModel: SectionSelectionViewModel

    /// Identifiable wrapper so an assessment can drive `fullScreenCover(item:)`.
    struct OpenAssessment: Identifiable {
        let id: UUID
    }

    // MARK: - Initialization

    init(previewMode: Bool = false) {
        let modelContext = ModelContainer.shared.mainContext
        _sectionViewModel = State(
            wrappedValue: SectionSelectionViewModel(modelContext: modelContext))

        if previewMode {
            // Initialize preview state
            _vetName = State(initialValue: "Dr. Smith")
            _farmName = State(initialValue: "Green Acres Farm")
            _visitDate = State(initialValue: Date())
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                MainScreen(
                    vetName: $vetName,
                    farmName: $farmName,
                    visitDate: $visitDate,
                    onStartNewAssessment: openAssessmentWorkspace
                )

                ScrollView {
                    PreviousAssessments(onOpen: openAssessmentWorkspace)
                }
            }
            .padding()
        }
        // The assessment workspace is a NavigationSplitView, which must be a
        // navigation root — pushing it onto a NavigationStack breaks its
        // detail-column navigation. Present it as a full-screen root instead.
        .fullScreenCover(item: $openAssessment) { open in
            AssessmentWorkspaceView(
                viewModel: sectionViewModel,
                galleryViewModel: GalleryViewModel(
                    sectionViewModel: sectionViewModel),
                assessmentId: open.id
            )
            .onAppear {
                // The workspace owns loading; saving happens on its
                // onDisappear, so reopening persists the previous one first.
                sectionViewModel.loadAssessment(id: open.id)
            }
        }
    }

    // MARK: - Navigation Methods

    private func openAssessmentWorkspace(assessmentId: UUID) {
        openAssessment = OpenAssessment(id: assessmentId)
    }
}

// MARK: - Previews

#Preview {
    ContentView()
        .modelContainer(for: Assessment.self, inMemory: true)
}

#Preview("Section Selection") {
    ContentView(previewMode: true)
        .modelContainer(for: Assessment.self, inMemory: true)
}
