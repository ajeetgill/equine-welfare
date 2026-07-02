import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var assessments: [Assessment]

    @State private var vetName = ""
    @State private var farmName = ""
    @State private var visitDate = Date()
    @State private var path: [AppDestination] = []
    @State private var sectionViewModel: SectionSelectionViewModel

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
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 24) {
                MainScreen(
                    vetName: $vetName,
                    farmName: $farmName,
                    visitDate: $visitDate,
                    onStartNewAssessment: startNewAssessment
                )

                ScrollView {
                    PreviousAssessments(path: $path)
                }
            }
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .assessment(let assessmentId):
                    AssessmentWorkspaceView(
                        viewModel: sectionViewModel,
                        galleryViewModel: GalleryViewModel(
                            sectionViewModel: sectionViewModel),
                        assessmentId: assessmentId
                    )
                    .onAppear {
                        // The workspace owns loading; saving happens on its
                        // onDisappear, so switching assessments persists the
                        // previous one before the next loads.
                        sectionViewModel.loadAssessment(id: assessmentId)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Navigation Methods

    private func startNewAssessment(assessmentId: UUID) {
        path.append(.assessment(id: assessmentId))
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
