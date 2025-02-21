import SwiftData
import Foundation

@Model
class Section {
    var name: String
    var isApplicable: Bool
    var subsections: [Subsection]
    var infoIconClicks: Int
    
    init(name: String, isApplicable: Bool = false) {
        self.name = name
        self.isApplicable = isApplicable
        self.subsections = []
        self.infoIconClicks = 0
    }
}