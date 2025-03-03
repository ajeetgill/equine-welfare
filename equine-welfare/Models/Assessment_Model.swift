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
    
    init(vetName: String, farmName: String, visitDate: Date) {
        self.id = UUID()
        self.vetName = vetName
        self.farmName = farmName
        self.visitDate = visitDate
        self.isComplete = false
        self.sections = []
        self.horses = []
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MMM-dd"
        return formatter.string(from: visitDate)
    }
    
    var displayName: String {
        "\(formattedDate)-\(vetName)-\(farmName)"
    }
}