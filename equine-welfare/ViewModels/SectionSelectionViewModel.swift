import SwiftUI
import SwiftData
import Observation

@Observable class SectionSelectionViewModel {
    var sections: [Section] = []
    var vetName: String = ""
    var farmName: String = ""
    var visitDate: Date = Date()
    var currentAssessmentId: UUID?
    var assessment: Assessment?
    
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
        self.assessment = newAssessment
        
        for section in sections {
            section.isApplicable = false
        }
        
        // Save the assessment
        saveAssessment()
        
        return newAssessment.id
    }
    
    // Load data for an existing assessment
    func loadAssessment(id: UUID) {
        if let assessment = assessmentHelper.editAssessment(assessmentId: id) {
            self.vetName = assessment.vetName
            self.farmName = assessment.farmName
            self.visitDate = assessment.visitDate
            self.currentAssessmentId = assessment.id
            self.sections = assessment.sections
            self.assessment = assessment
        }
    }
    
    // Save current assessment
    func saveAssessment() {
        guard let id = currentAssessmentId,
              let assessment = assessmentHelper.editAssessment(assessmentId: id) else {
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
    
    // Add computed property to access current assessment
    var currentAssessment: Assessment? {
        guard let id = currentAssessmentId else { return nil }
        return assessmentHelper.editAssessment(assessmentId: id)
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
        saveAssessment()
    }
    
    func isSectionApplicable(_ id: Int) -> Bool {
        sections.first(where: { $0.id == id })?.isApplicable ?? false
    }
    
//    // Save when returning to home
//    func prepareForReturn(completion: @escaping () -> Void) {
//        saveAssessment()
//        completion()
//    }

    // MARK: - Section Status Management
    func getSectionStatus(_ section: Section) -> SectionCompletionStatus {
        guard section.isApplicable else {
            return .notStarted
        }

        var hasStarted = false
        var allCompleted = true

        for subsection in section.subsections {
            for requirement in subsection.requirements {
                if requirement.complianceStatus != nil {
                    hasStarted = true
                }
                if requirement.complianceStatus == nil {
                    allCompleted = false
                }
            }
        }

        if allCompleted {
            return .completed
        } else if hasStarted {
            return .inProgress
        }
        return .notStarted
    }

    func getSectionProgress(_ section: Section) -> (Int, Int) {
        var completed = 0
        var total = 0

        for subsection in section.subsections {
            for requirement in subsection.requirements {
                total += 1
                if requirement.complianceStatus != nil {
                    completed += 1
                }
            }
        }

        return (completed, total)
    }
}
