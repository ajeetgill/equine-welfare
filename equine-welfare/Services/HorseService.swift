import SwiftData
import Foundation

class HorseService {
    
    static func fetchHorses(modelContext: ModelContext, forAssessment assessmentId: UUID? = nil) -> [Horse] {
        var fetchDescriptor = FetchDescriptor<Horse>()
        
        if let assessmentId = assessmentId {
            fetchDescriptor.predicate = #Predicate<Horse> { 
                $0.assessment?.id == assessmentId
            }
        }
        
        do {
            let horses = try modelContext.fetch(fetchDescriptor)
            return horses
        } catch {
            return []
        }
    }
    
    static func encodeHorsesToJSON(horses: [Horse]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        // Create a dictionary with only the fields we want to encode
        let horseDicts = horses.map { horse -> [String: Any] in
            var dict: [String: Any] = [
                "uuid": horse.uuid.uuidString,
                "name": horse.name,
                "age": horse.age,
                "color": horse.color,
                "sex": horse.sex,
                "breed": horse.breed,
                "timeOnFarm": horse.timeOnFarm,
                "bcsScore": horse.bcsScore,
                "ageUnit": horse.ageUnit.rawValue,
                "timeUnit": horse.timeUnit.rawValue,
                "isHorse": horse.isHorse
            ]
            
            // Add optional fields if they exist
            if let otherBreed = horse.otherBreed {
                dict["otherBreed"] = otherBreed
            }
            
            if let notes = horse.notes {
                dict["notes"] = notes
            }
            
            return dict
        }
        
        do {
            return try JSONSerialization.data(withJSONObject: horseDicts, options: .prettyPrinted)
        } catch {
            return nil
        }
    }
}
