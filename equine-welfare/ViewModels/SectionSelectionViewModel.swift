import SwiftUI
import SwiftData

class SectionSelectionViewModel: ObservableObject {
    @Published var sections: [Section] = []
    @Published var vetName: String = ""
    @Published var farmName: String = ""
    @Published var visitDate: Date = Date()
    @Published var currentAssessmentId: UUID?
    
    private let modelContext: ModelContext
    private let assessmentHelper: AssessmentHelper
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.assessmentHelper = AssessmentHelper(modelContext: modelContext)
        loadDefaultSections()
    }
    
    private func loadDefaultSections() {
        sections = COPService.loadSections()
    }
    
    private func createFreshSections() -> [Section] {
        let defaultSections = COPService.loadSections()
        var freshSections: [Section] = []
        
        for section in defaultSections {
            let newSection = Section(id: section.id, title: section.title)
            
            for subsection in section.subsections {
                let newSubsection = Subsection(name: subsection.name)
                
                for requirement in subsection.requirements {
                    let newRequirement = Requirement(text: requirement.text)
                    newSubsection.requirements.append(newRequirement)
                }
                
                newSection.subsections.append(newSubsection)
            }
            
            freshSections.append(newSection)
        }
        
        return freshSections
    }
    
    // Reset and prepare for a new assessment
    func createNewAssessment(vetName: String, farmName: String, visitDate: Date) -> UUID {
        let freshSections = createFreshSections()
        
        let newAssessment = assessmentHelper.createAssessment(
            vetName: vetName,
            farmName: farmName,
            visitDate: visitDate,
            sections: freshSections,
            horses: []
        )
        
        self.vetName = vetName
        self.farmName = farmName
        self.visitDate = visitDate
        self.currentAssessmentId = newAssessment.id
        self.sections = freshSections
        
        for section in sections {
            section.isApplicable = false
        }
        
        // Save the assessment
        saveAssessment()
        
        return newAssessment.id
    }
    
    // Load data for an existing assessment
    func loadAssessment(id: UUID) {
        if let assessment = assessmentHelper.loadAssessment(id: id) {
            vetName = assessment.vetName
            farmName = assessment.farmName
            visitDate = assessment.visitDate
            currentAssessmentId = assessment.id
            
            sections = assessment.sections
        }
    }
    
    // Save current assessment
    func saveAssessment() {
        guard let id = currentAssessmentId,
              let assessment = assessmentHelper.loadAssessment(id: id) else {
            return // Don't create new assessment here
        }
        
        // Only update existing assessment
        assessmentHelper.updateAssessment(
            assessment: assessment,
            vetName: vetName,
            farmName: farmName,
            visitDate: visitDate,
            sections: sections,
            horses: assessment.horses
        )
    }
    
    // MARK: - Section Management
    
    var applicableSections: [Section] {
        sections.sorted { $0.id < $1.id }.filter { $0.isApplicable }
    }
    
    var nonApplicableSections: [Section] {
        sections.sorted { $0.id < $1.id }.filter { !$0.isApplicable }
    }
    
    func toggleSection(_ id: Int) {
        if let section = sections.first(where: { $0.id == id }) {
            section.isApplicable.toggle()
        }
    }
    
    func isSectionApplicable(_ id: Int) -> Bool {
        sections.first(where: { $0.id == id })?.isApplicable ?? false
    }
    
    // Save when returning to home
    func prepareForReturn(completion: @escaping () -> Void) {
        saveAssessment()
        completion()
    }
}