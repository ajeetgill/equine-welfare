import SwiftUI
import SwiftData

class AssessmentHelper {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func createAssessment(vetName: String, farmName: String, visitDate: Date, sections: [Section], horses: [Horse]) -> Assessment {
        let newAssessment = Assessment(
            vetName: vetName,
            farmName: farmName,
            visitDate: visitDate
        )
        
        // Add sections
        for section in sections {
            newAssessment.sections.append(section)
            modelContext.insert(section)
        }
        
        // Add horses
        for horse in horses {
            newAssessment.horses.append(horse)
            modelContext.insert(horse)
        }
        
        modelContext.insert(newAssessment)
        modelContext.saveOrLog("create assessment")
        return newAssessment
    }
    
    /// Edit an existing assessment
    func editAssessment(assessmentId: UUID) -> Assessment? {
        let descriptor = FetchDescriptor<Assessment>(
            predicate: #Predicate { $0.id == assessmentId }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    func updateAssessment(assessment: Assessment, vetName: String, farmName: String, visitDate: Date, sections: [Section], horses: [Horse]) {
        assessment.vetName = vetName
        assessment.farmName = farmName
        assessment.visitDate = visitDate
        
        // Update sections
        assessment.sections.removeAll()
        for section in sections {
            assessment.sections.append(section)
            modelContext.insert(section)
        }
        
        // Update horses
        assessment.horses.removeAll()
        for horse in horses {
            assessment.horses.append(horse)
            modelContext.insert(horse)
        }

        modelContext.saveOrLog("update assessment")
    }

    func deleteAssessment(assessment: Assessment) {
        modelContext.delete(assessment)
        modelContext.saveOrLog("delete assessment")
    }
} 
