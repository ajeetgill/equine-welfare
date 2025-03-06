import SwiftUI

/// Manages navigation state for the entire application
class NavigationState: ObservableObject {
    // MARK: - Navigation State
    
    /// Represents different screens in the application
    enum Screen {
        case main
        case sectionSelection(assessmentId: UUID?)
        case horses(assessmentId: UUID?)
        case horseInfo(horseId: UUID)
        case horseDetail(horseId: UUID?)
    }
    
    /// Current screen being displayed
    @Published var currentScreen: Screen = .main
    
    /// Currently active assessment ID
    @Published var currentAssessmentId: UUID?
    
    /// Currently selected section ID (nil when on section selection screen)
    @Published var selectedSectionId: Int? = nil
    

    /// Currently selected horse ID
    @Published var selectedHorseId: UUID? = nil
    /// Flag to show gallery view instead of section selection or section detail
    @Published var showingGallery: Bool = false
    
    // MARK: - Navigation Methods
    
    /// Start a new assessment and navigate to section selection
    func startNewAssessment(vetName: String, farmName: String, visitDate: Date) {
        // Note: currentAssessmentId should already be set before calling this method
        currentScreen = .sectionSelection(assessmentId: currentAssessmentId)
        selectedSectionId = nil // Clear any selected section
        showingGallery = false // Reset gallery view
    }
    
    /// Edit an existing assessment
    func editAssessment(assessmentId: UUID) {
        currentAssessmentId = assessmentId
        currentScreen = .sectionSelection(assessmentId: assessmentId)
        selectedSectionId = nil // Clear any selected section
        showingGallery = false // Reset gallery view
    }
    
    /// Return to the main screen
    func returnToMain() {
        // Clear the assessment ID when returning to main
        currentAssessmentId = nil
        currentScreen = .main
        selectedSectionId = nil // Clear any selected section
        showingGallery = false // Reset gallery view
    }
    
    /// Show the section selection screen for the current assessment
    func showSectionSelection() {
        selectedSectionId = nil  // Clear the selected section ID
        currentScreen = .sectionSelection(assessmentId: currentAssessmentId)
    }
    
    /// Show the horses screen for the current assessment
    func showHorses() {
        selectedSectionId = nil  // Clear the selected section ID
        currentScreen = .horses(assessmentId: currentAssessmentId)
    }
    
    /// Show the horse detail screen for a specific horse
    func showHorseDetail(horseId: UUID? = nil) {
        currentScreen = .horseDetail(horseId: horseId)
    }
    
    /// Show the horse info screen for a specific horse
    func showHorseInfo(horseId: UUID) {
        currentScreen = .horseInfo(horseId: horseId)
    }
    
    /// Show the add horse screen
    func showAddHorse() {
        currentScreen = .horseDetail(horseId: nil)
    }
    
    /// Navigate to a specific section
    func navigateToSection(sectionId: Int) {
        selectedSectionId = sectionId
        showingGallery = false // Reset gallery view
        currentScreen = .sectionSelection(assessmentId: currentAssessmentId)
    }
    
    /// Show the gallery view
    func showGallery() {
        selectedSectionId = nil // Clear any selected section when showing gallery
        showingGallery = true
        currentScreen = .sectionSelection(assessmentId: currentAssessmentId)
    }
} 