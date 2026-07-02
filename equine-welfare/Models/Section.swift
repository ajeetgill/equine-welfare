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

// For sections or any other model used in navigation
extension Section: Identifiable, Hashable {
    // If id is already a property, Identifiable may be automatic
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Section, rhs: Section) -> Bool {
        lhs.id == rhs.id
    }
}