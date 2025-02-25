import SwiftUI
import SwiftData

class SectionSelectionViewModel: ObservableObject {
    @Published var sections: [AssessmentSection] = []
    @Published var vetName: String = ""
    @Published var farmName: String = ""
    @Published var visitDate: Date = Date()
    @Published var currentAssessmentId: UUID?
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadDefaultSections()
    }
    
    private func loadDefaultSections() {
        sections = [
            AssessmentSection(id: 1, title: "Duty of Care"),
            AssessmentSection(id: 2, title: "Facilities and Housing"),
            AssessmentSection(id: 3, title: "Feed and Water"),
            AssessmentSection(id: 4, title: "Health Management"),
            AssessmentSection(id: 5, title: "Feedlot Management"),
            AssessmentSection(id: 6, title: "Husbandry Practices"),
            AssessmentSection(id: 7, title: "Reproductive Management"),
            AssessmentSection(id: 8, title: "Transportation"),
            AssessmentSection(id: 9, title: "Change or End of Career"),
            AssessmentSection(id: 10, title: "Euthanasia")
        ]
    }
    
    // Reset and prepare for a new assessment
    func createNewAssessment(vetName: String, farmName: String, visitDate: Date) {
        // Reset the current assessment ID to ensure we create a new one
        currentAssessmentId = nil
        
        // Set form data
        self.vetName = vetName
        self.farmName = farmName
        self.visitDate = visitDate
        
        // Reset all sections to not applicable
        for i in 0..<sections.count {
            sections[i].isApplicable = false
        }
    }
    
    // Load data for an existing assessment
    func loadAssessment(id: UUID) {
        let descriptor = FetchDescriptor<Assessment>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            if let assessment = try modelContext.fetch(descriptor).first {
                vetName = assessment.vetName
                farmName = assessment.farmName
                visitDate = assessment.visitDate
                currentAssessmentId = assessment.id
                
                // Reset sections first
                for i in 0..<sections.count {
                    sections[i].isApplicable = false
                }
                
                // Update sections with stored selections
                for selection in assessment.sectionSelections {
                    if let index = sections.firstIndex(where: { $0.id == selection.sectionId }) {
                        sections[index].isApplicable = selection.isApplicable
                    }
                }
            }
        } catch {
            print("Failed to load assessment: \(error)")
        }
    }
    
    // Save current assessment
    func saveAssessment() {
        if let id = currentAssessmentId {
            // Update existing assessment
            let descriptor = FetchDescriptor<Assessment>(
                predicate: #Predicate { $0.id == id }
            )
            
            do {
                if let assessment = try modelContext.fetch(descriptor).first {
                    assessment.vetName = vetName
                    assessment.farmName = farmName
                    assessment.visitDate = visitDate
                    
                    // Remove existing selections
                    assessment.sectionSelections.removeAll()
                    
                    // Add new selections
                    for section in sections {
                        let selection = SectionSelection(
                            sectionId: section.id,
                            title: section.title,
                            isApplicable: section.isApplicable
                        )
                        assessment.sectionSelections.append(selection)
                        modelContext.insert(selection)
                    }
                    
                    try modelContext.save()
                }
            } catch {
                print("Failed to update assessment: \(error)")
            }
        } else {
            // Create a completely new assessment
            let newAssessment = Assessment(
                vetName: vetName,
                farmName: farmName,
                visitDate: visitDate
            )
            
            // Add sections
            for section in sections {
                let selection = SectionSelection(
                    sectionId: section.id,
                    title: section.title,
                    isApplicable: section.isApplicable
                )
                newAssessment.sectionSelections.append(selection)
            }
            
            modelContext.insert(newAssessment)
            currentAssessmentId = newAssessment.id
            
            try? modelContext.save()
        }
    }
    
    // MARK: - Section Management
    
    var applicableSections: [AssessmentSection] {
        sections.filter { $0.isApplicable }
    }
    
    var nonApplicableSections: [AssessmentSection] {
        sections.filter { !$0.isApplicable }
    }
    
    func toggleSection(_ id: Int) {
        if let index = sections.firstIndex(where: { $0.id == id }) {
            sections[index].isApplicable.toggle()
        }
    }
    
    func isSectionApplicable(_ id: Int) -> Bool {
        if let section = sections.first(where: { $0.id == id }) {
            return section.isApplicable
        }
        return false
    }
    
    // Save when returning to home
    func prepareForReturn(completion: @escaping () -> Void) {
        saveAssessment()
        completion()
    }
}