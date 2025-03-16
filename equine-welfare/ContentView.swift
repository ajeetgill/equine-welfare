import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var assessments: [Assessment]

    @State private var vetName = ""
    @State private var farmName = ""
    @State private var visitDate = Date()
    @State private var currentAssessmentId: UUID?
    @State private var selectedSectionId: Int?
    @State private var navigationPath = NavigationPath()
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
        NavigationStack(path: $navigationPath) {
            VStack(alignment: .leading, spacing: 24) {
                MainScreen(
                    vetName: $vetName,
                    farmName: $farmName,
                    visitDate: $visitDate,
                    onStartNewAssessment: startNewAssessment
                )

                ScrollView {
                    PreviousAssessments(navigationPath: $navigationPath)
                }
            }
            .navigationDestination(for: AppDestination.self) {
                destination in
                switch destination {
                case .sectionSelection(let assessmentId):
                    AssessmentSidebarView(
                        onShowSectionSelection: {},
                        viewModel: sectionViewModel,
                        galleryViewModel: GalleryViewModel(
                            sectionViewModel: sectionViewModel),
                        navigationPath: $navigationPath,
                        assessmentId: assessmentId
                    )
                    .onAppear {
                        currentAssessmentId = assessmentId
                        selectedSectionId = nil
                        loadAssessment(id: assessmentId)
                    }

                case .sectionDetail(let sectionId):
                    if let section = sectionViewModel.sections.first(
                        where: { $0.id == sectionId })
                    {
                        SectionDetailView(section: section)
                    } else {
                        Text("Section not found")
                    }
                    
                case .horses(let assessmentId):
                    HorsesView(
                        assessmentId: assessmentId,
                        navigationPath: $navigationPath
                    )
                    .onAppear {
                        currentAssessmentId = assessmentId
                        loadAssessment(id: assessmentId)
                    }
                    
                case .horseInfo(let horseId):
                    HorseInfoView(
                        horseId: horseId,
                        navigationPath: $navigationPath
                    )
                    
                case .horseDetail(let horseId, let assessmentId):
                    HorseDetailView(
                        horseId: horseId,
                        assessmentId: assessmentId,
                        navigationPath: $navigationPath
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Navigation Methods

    private func startNewAssessment(assessmentId: UUID) {
        currentAssessmentId = assessmentId
        navigationPath.append(
            AppDestination.sectionSelection(assessmentId: assessmentId))
    }

    private func editAssessment(assessmentId: UUID) {
        currentAssessmentId = assessmentId
        navigationPath.append(
            AppDestination.sectionSelection(assessmentId: assessmentId))
    }

    private func returnToMain() {
        // Save any pending changes
        sectionViewModel.saveAssessment()

        // Clear state and navigation
        currentAssessmentId = nil
        selectedSectionId = nil
        navigationPath = NavigationPath()

        // Reset form fields to prevent previous assessment data from appearing in new form
        vetName = ""
        farmName = ""
        visitDate = Date()
    }

    private func showSectionSelection() {
        selectedSectionId = nil
        if navigationPath.count > 0 {
            navigationPath.removeLast(navigationPath.count)
        }
        if let assessmentId = currentAssessmentId {
            navigationPath.append(
                AppDestination.sectionSelection(assessmentId: assessmentId))
        }
    }

    private func loadAssessment(id: UUID) {
        // Only create a new view model if needed
        //        if sectionViewModel == nil {
        //            sectionViewModel = SectionSelectionViewModel(
        //                modelContext: modelContext)
        //        }

        // Save any pending changes first if we're switching assessments
        if let currentId = currentAssessmentId, currentId != id {
            sectionViewModel.saveAssessment()
        }

        // Update the current assessment ID
        currentAssessmentId = id

        // Load the assessment on a background task
        sectionViewModel.loadAssessment(id: id)
//        Task {
//            await sectionViewModel.loadAssessment(id: id)
//        }
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
