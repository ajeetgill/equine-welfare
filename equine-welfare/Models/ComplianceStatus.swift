import Foundation

enum ComplianceStatus: String, Codable, CaseIterable {
    case compliant = "Compliant"
    case notCompliant = "Not Compliant"
    case notApplicable = "N/A"
}
