import SwiftData
import Foundation

@Model
class Assessment {
    var id: UUID
    var vetName: String
    var farmName: String
    var visitDate: Date
    @Relationship(deleteRule: .cascade) var sections: [Section]
    var isComplete: Bool
    @Relationship(deleteRule: .cascade) var horses: [Horse]
    
    var sideNotes: String?
    
    init(vetName: String, farmName: String, visitDate: Date) {
        self.id = UUID()
        self.vetName = vetName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "-")
        self.farmName = farmName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "-")
        self.visitDate = visitDate
        self.isComplete = false
        self.sections = []
        self.horses = []
        self.sideNotes = nil
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MMM-dd"
        return formatter.string(from: visitDate).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var displayName: String {
        "\(formattedDate)-\(vetName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "-"))-\(farmName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "-"))"
    }
}
