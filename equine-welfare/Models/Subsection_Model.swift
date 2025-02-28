import SwiftData
import Foundation

@Model
class Subsection {
    var name: String
    @Relationship(deleteRule: .cascade) var requirements: [Requirement]
    
    init(name: String) {
        self.name = name
        self.requirements = []
    }
}