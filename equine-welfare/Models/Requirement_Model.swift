import SwiftData
import Foundation

@Model
class Requirement {
    var text: String
    var complianceStatus: ComplianceStatus
    var nonComplianceReason: String?
    
    init(text: String, complianceStatus: ComplianceStatus = .compliant) {
        self.text = text
        self.complianceStatus = complianceStatus
        self.nonComplianceReason = nil
    }
}