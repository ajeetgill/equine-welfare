import SwiftData
import Foundation

@Model
class Requirement {
    var text: String
    var complianceStatus: ComplianceStatus?
    var nonComplianceReason: String?
    @Relationship(deleteRule: .cascade) var mediaAttachments: [MediaAttachment]
    
    init(text: String) {
        self.text = text
        self.complianceStatus = nil
        self.nonComplianceReason = nil
        self.mediaAttachments = []
    }
}