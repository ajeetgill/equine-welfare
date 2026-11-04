import Foundation
import SwiftData
import Testing
@testable import Horse_C_O_P

/// Content tests for the RTF report extracted out of PreviousAssessmentRow.
/// Asserts on the report's text, not its styling, so formatting tweaks stay
/// cheap while the *content* contract (what a vet reads) is locked.
struct RTFReportTests {
    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        container = try ModelContainer(
            for: Assessment.self, Section.self, Subsection.self,
            Requirement.self, Horse.self, MediaAttachment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    private func makeAssessment(vetName: String = "Dr. Jane Smith",
                                farmName: String = "Green Acres") -> Assessment {
        let assessment = Assessment(vetName: vetName, farmName: farmName, visitDate: .now)
        context.insert(assessment)
        return assessment
    }

    private func addSection(_ id: Int, to assessment: Assessment, applicable: Bool = true,
                            requirements: [(text: String, status: ComplianceStatus?, reason: String?)]) {
        let section = Section(id: id, title: "Title \(id)", isApplicable: applicable)
        let subsection = Subsection(name: "Subsection \(id)")
        subsection.requirements = requirements.map { spec in
            let requirement = Requirement(text: spec.text)
            requirement.complianceStatus = spec.status
            requirement.nonComplianceReason = spec.reason
            return requirement
        }
        section.subsections = [subsection]
        assessment.sections.append(section)
    }

    @Test func reportHeaderShowsVetFarmAndDate() {
        let assessment = makeAssessment()
        let text = AssessmentRTFReport.content(for: assessment).string
        #expect(text.contains("Assessment Report"))
        #expect(text.contains("Vet Name: Dr.-Jane-Smith"))
        #expect(text.contains("Farm Name: Green-Acres"))
        #expect(text.contains("Date of Visit: \(assessment.formattedDate)"))
    }

    @Test func reportListsOnlyNonCompliantRequirementsWithReasons() {
        let assessment = makeAssessment()
        addSection(1, to: assessment, requirements: [
            ("Shelter available", .compliant, nil),
            ("Paddock drainage adequate", .notCompliant, "Muddy paddock"),
            ("Airflow acceptable", nil, nil),
        ])
        addSection(2, to: assessment, applicable: false, requirements: [
            ("Feed stored properly", .notCompliant, "Should not appear"),
        ])

        let text = AssessmentRTFReport.content(for: assessment).string

        #expect(text.contains("Section 1: Title 1"))
        #expect(text.contains("Paddock drainage adequate"))
        #expect(text.contains("Status: Not Compliant"))
        #expect(text.contains("Reason for non-compliance: Muddy paddock"))

        #expect(!text.contains("Shelter available"), "compliant requirements are excluded")
        #expect(!text.contains("Airflow acceptable"), "unevaluated requirements are excluded")
        #expect(!text.contains("Feed stored properly"), "non-applicable sections are excluded")
        #expect(!text.contains("No non-compliant requirements found."))
    }

    @Test func fullyCompliantReportSaysSo() {
        let assessment = makeAssessment()
        addSection(1, to: assessment, requirements: [("Shelter available", .compliant, nil)])
        let text = AssessmentRTFReport.content(for: assessment).string
        #expect(text.contains("No non-compliant requirements found."))
        #expect(!text.contains("Section 1:"))
    }

    @Test func requirementWithoutReasonOmitsReasonLine() {
        let assessment = makeAssessment()
        addSection(1, to: assessment, requirements: [("Paddock drainage adequate", .notCompliant, nil)])
        let text = AssessmentRTFReport.content(for: assessment).string
        #expect(text.contains("Status: Not Compliant"))
        #expect(!text.contains("Reason for non-compliance:"))
    }

    @Test func temporaryFileURLWritesRTFNamedAfterAssessment() throws {
        let assessment = makeAssessment()
        addSection(1, to: assessment, requirements: [("Req", .notCompliant, "Bad")])

        let url = try #require(AssessmentRTFReport.temporaryFileURL(for: assessment))
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.lastPathComponent == "\(assessment.displayName).rtf")
        let data = try Data(contentsOf: url)
        #expect(String(decoding: data.prefix(6), as: UTF8.self).hasPrefix("{\\rtf"))
    }

    @Test func temporaryFileNameSanitizesSlashes() throws {
        let assessment = makeAssessment(farmName: "Green/Acres")
        let url = try #require(AssessmentRTFReport.temporaryFileURL(for: assessment))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(!url.lastPathComponent.contains("/"))
        #expect(url.lastPathComponent.hasSuffix("Green-Acres.rtf"))
    }
}
