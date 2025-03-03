import SwiftUI

/// Manages navigation state for the entire application
class NavigationState: ObservableObject {
    // MARK: - Navigation State
    
    /// Represents different screens in the application
    enum Screen {
        case main
        case sectionSelection(assessmentId: UUID?)
    }
    
    /// Current screen being displayed
    @Published var currentScreen: Screen = .main
    
    /// Currently active assessment ID
    @Published var currentAssessmentId: UUID?
    
    /// Currently selected section ID (nil when on section selection screen)
    @Published var selectedSectionId: Int? = nil
    
    // MARK: - Navigation Methods
    
    /// Start a new assessment and navigate to section selection
    func startNewAssessment(vetName: String, farmName: String, visitDate: Date) {
        // Note: currentAssessmentId should already be set before calling this method
        currentScreen = .sectionSelection(assessmentId: currentAssessmentId)
        selectedSectionId = nil // Clear any selected section
    }
    
    /// Edit an existing assessment
    func editAssessment(assessmentId: UUID) {
        currentAssessmentId = assessmentId
        currentScreen = .sectionSelection(assessmentId: assessmentId)
        selectedSectionId = nil // Clear any selected section
    }
    
    /// Return to the main screen
    func returnToMain() {
        // Clear the assessment ID when returning to main
        currentAssessmentId = nil
        currentScreen = .main
        selectedSectionId = nil // Clear any selected section
    }
    
    /// Show the section selection screen for the current assessment
    func showSectionSelection() {
        selectedSectionId = nil // Clear any selected section
        currentScreen = .sectionSelection(assessmentId: currentAssessmentId)
    }
} 