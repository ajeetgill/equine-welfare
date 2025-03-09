//
//  ContentView.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 19/02/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var assessments: [Assessment]
    
    @StateObject private var navigationState = NavigationState()
    @State private var vetName = ""
    @State private var farmName = ""
    @State private var visitDate = Date()
    @StateObject private var sectionViewModel: SectionSelectionViewModel
    
    // MARK: - Initialization
    
    init(previewMode: Bool = false) {
        let modelContext = ModelContainer.shared.mainContext
        _sectionViewModel = StateObject(wrappedValue: SectionSelectionViewModel(modelContext: modelContext))
        
        if previewMode {
            // Initialize preview state
            let previewState = NavigationState()
            previewState.currentScreen = .sectionSelection(assessmentId: nil)
            _navigationState = StateObject(wrappedValue: previewState)
            _vetName = State(initialValue: "Dr. Smith")
            _farmName = State(initialValue: "Green Acres Farm")
            _visitDate = State(initialValue: Date())
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationSplitView {
            // MARK: Sidebar Content
            sidebarContent
        } detail: {
            // MARK: Detail Content
            detailContent
        }
        .environmentObject(navigationState)
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var sidebarContent: some View {
        switch navigationState.currentScreen {
        case .main:
            SidebarMainScreen()
        case .sectionSelection(let assessmentId), .horses(let assessmentId):
            AssessmentSidebarView(viewModel: sectionViewModel)
                .onAppear {
                    handleAssessmentAppearance(assessmentId: assessmentId)
                }
        case .horseDetail:
            AssessmentSidebarView(viewModel: sectionViewModel)
                .onAppear {
                    handleAssessmentAppearance(assessmentId: navigationState.currentAssessmentId)
                }
        }
    }
    
    @ViewBuilder
    private var detailContent: some View {
        switch navigationState.currentScreen {
        case .main:
            VStack(alignment: .leading, spacing: 24) {
                MainScreen(
                    vetName: $vetName,
                    farmName: $farmName,
                    visitDate: $visitDate,
                    navigationState: navigationState
                )
                
                ScrollView {
                    PreviousAssessments()
                }
            }
            .padding()
            
        case .sectionSelection:
            if let sectionId = navigationState.selectedSectionId,
               let section = sectionViewModel.sections.first(where: { $0.id == sectionId }) {
                // Show the section detail view
                SectionDetailView(section: section)
            } else {
                // Show the section selection view
                SectionSelectionView(viewModel: sectionViewModel)
            }
            
        case .horses:
            // Show the horses view
            HorsesView()
            
        case .horseDetail(let horseId):
            // We need to fetch the horse with the given ID and show its detail view
            if let id = horseId,
               let horse = try? modelContext.fetch(
                FetchDescriptor<Horse>(predicate: #Predicate { $0.uuid == id })
               ).first {
                HorseDetailView(horse: horse)
            } else {
                // For adding a new horse
                HorseDetailView()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleAssessmentAppearance(assessmentId: UUID?) {
        if let id = assessmentId ?? navigationState.currentAssessmentId {
            // Load existing assessment
            sectionViewModel.loadAssessment(id: id)
        }
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
