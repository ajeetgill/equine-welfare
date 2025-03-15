import SwiftUI

/// Defines all possible navigation destinations in the app
enum AppDestination: Hashable {
    /// Section selection screen for an assessment
    case sectionSelection(assessmentId: UUID)
    
    /// Detail view for a specific section
    case sectionDetail(sectionId: Int)
    
    // Implement Hashable conformance
    func hash(into hasher: inout Hasher) {
        switch self {
        case .sectionSelection(let id):
            hasher.combine("sectionSelection")
            hasher.combine(id)
        case .sectionDetail(let id):
            hasher.combine("sectionDetail")
            hasher.combine(id)
        }
    }
    
    static func == (lhs: AppDestination, rhs: AppDestination) -> Bool {
        switch (lhs, rhs) {
        case (.sectionSelection(let id1), .sectionSelection(let id2)):
            return id1 == id2
        case (.sectionDetail(let id1), .sectionDetail(let id2)):
            return id1 == id2
        default:
            return false
        }
    }
} 