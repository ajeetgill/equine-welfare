import SwiftData
import Foundation

@Model
class Section {
    var id: Int
    var title: String
    var isApplicable: Bool
    var subsections: [Subsection]
    var infoIconClicks: Int
    
    @Relationship(inverse: \Assessment.sections) var assessment: Assessment?
    
    init(id: Int, title: String, isApplicable: Bool = false) {
        self.id = id
        self.title = title
        self.isApplicable = isApplicable
        self.subsections = []
        self.infoIconClicks = 0
    }
}