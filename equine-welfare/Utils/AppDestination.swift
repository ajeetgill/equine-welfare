import SwiftUI

/// Defines all possible navigation destinations in the app
enum AppDestination: Hashable {
    /// Overview screen for an assessment
    case overview(assessmentId: UUID)
    
    /// Section selection screen for an assessment
    case sectionSelection(assessmentId: UUID)
    
    /// Detail view for a specific section
    case sectionDetail(sectionId: Int)
    
    /// Horses list screen for an assessment
//    case horses(assessmentId: UUID)
    
    /// Horse info view for a specific horse
//    case horseInfo(horseId: UUID)
    
    /// Horse detail/edit view for a specific horse (nil for new horse)
//    case horseDetail(horseId: UUID?, assessmentId: UUID)
    
    // Implement Hashable conformance
    func hash(into hasher: inout Hasher) {
        switch self {
        case .overview(let id):
            hasher.combine("overview")
            hasher.combine(id)
        case .sectionSelection(let id):
            hasher.combine("sectionSelection")
            hasher.combine(id)
        case .sectionDetail(let id):
            hasher.combine("sectionDetail")
            hasher.combine(id)
//        case .horses(let id):
//            hasher.combine("horses")
//            hasher.combine(id)
//        case .horseInfo(let id):
//            hasher.combine("horseInfo")
//            hasher.combine(id)
//        case .horseDetail(let horseId, let assessmentId):
//            hasher.combine("horseDetail")
//            hasher.combine(horseId)
//            hasher.combine(assessmentId)
        }
    }
    
    static func == (lhs: AppDestination, rhs: AppDestination) -> Bool {
        switch (lhs, rhs) {
        case (.overview(let id1), .overview(let id2)):
            return id1 == id2
        case (.sectionSelection(let id1), .sectionSelection(let id2)):
            return id1 == id2
        case (.sectionDetail(let id1), .sectionDetail(let id2)):
            return id1 == id2
//        case (.horses(let id1), .horses(let id2)):
//            return id1 == id2
//        case (.horseInfo(let id1), .horseInfo(let id2)):
//            return id1 == id2
//        case (.horseDetail(let id1, let assessId1), .horseDetail(let id2, let assessId2)):
//            return id1 == id2 && assessId1 == assessId2
        default:
            return false
        }
    }
}
