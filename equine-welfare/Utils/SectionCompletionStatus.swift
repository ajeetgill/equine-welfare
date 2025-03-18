import SwiftUI

/// Tracks the completion status of a section
enum SectionCompletionStatus {
    case notStarted
    case inProgress
    case completed
    
    /// Returns the appropriate color based on the status
    var color: Color {
        switch self {
        case .notStarted:
            return .gray
        case .inProgress, .completed:
            return .blue
        }
    }
}