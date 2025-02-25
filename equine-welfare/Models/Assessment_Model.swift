import SwiftData
import Foundation

@Model
class Assessment {
    var id: UUID
    var vetName: String
    var farmName: String
    var visitDate: Date
    var sections: [Section]
    var horses: [Horse]
    
    
    init(vetName: String, farmName: String, visitDate: Date) {
        self.id = UUID()
        self.vetName = vetName
        self.farmName = farmName
        self.visitDate = visitDate
        self.sections = []
        self.horses = []
    }
}