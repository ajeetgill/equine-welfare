import SwiftUI

struct AssessmentSection: Identifiable {
    var id: Int
    var title: String
    var isApplicable: Bool = false
    var hasInfo: Bool = true
}
