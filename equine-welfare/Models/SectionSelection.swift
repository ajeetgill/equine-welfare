import Foundation
import SwiftData

@Model
final class SectionSelection {
    var sectionId: Int
    var title: String
    var isApplicable: Bool
    
    init(sectionId: Int, title: String, isApplicable: Bool) {
        self.sectionId = sectionId
        self.title = title
        self.isApplicable = isApplicable
    }
} 