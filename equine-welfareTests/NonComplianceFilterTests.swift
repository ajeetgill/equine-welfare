import Foundation
import SwiftData
import Testing
@testable import Horse_C_O_P

/// The non-compliance filters drive both the on-screen preview and every
/// exported report (RTF today, extracted report generator tomorrow). These
/// tests pin their meaning so the god-file split can't change what a report
/// considers "non-compliant".
struct NonComplianceFilterTests {
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

    private func makeAssessment() -> Assessment {
        let assessment = Assessment(vetName: "Vet", farmName: "Farm", visitDate: .now)
        context.insert(assessment)
        return assessment
    }

    private func makeSection(id: Int, applicable: Bool, statuses: [ComplianceStatus?]) -> Section {
        let section = Section(id: id, title: "Section \(id)", isApplicable: applicable)
        let subsection = Subsection(name: "Sub \(id)")
        subsection.requirements = statuses.enumerated().map { index, status in
            let requirement = Requirement(text: "Req \(id).\(index)")
            requirement.complianceStatus = status
            return requirement
        }
        section.subsections = [subsection]
        return section
    }

    @Test func notApplicableSectionIsExcludedEvenWithNonCompliantRequirements() {
        let assessment = makeAssessment()
        assessment.sections = [
            makeSection(id: 1, applicable: false, statuses: [.notCompliant]),
            makeSection(id: 2, applicable: true, statuses: [.compliant]),
        ]
        #expect(assessment.nonCompliantSections.isEmpty)
    }

    @Test func nonCompliantSectionsAreSortedById() {
        let assessment = makeAssessment()
        assessment.sections = [
            makeSection(id: 5, applicable: true, statuses: [.notCompliant]),
            makeSection(id: 1, applicable: true, statuses: [.notCompliant]),
            makeSection(id: 3, applicable: true, statuses: [.compliant]),
        ]
        #expect(assessment.nonCompliantSections.map(\.id) == [1, 5])
    }

    @Test func fullyCompliantAssessmentHasNoNonCompliantSections() {
        let assessment = makeAssessment()
        assessment.sections = [
            makeSection(id: 1, applicable: true, statuses: [.compliant, .notApplicable, nil]),
        ]
        #expect(assessment.nonCompliantSections.isEmpty)
    }

    @Test func subsectionFilterKeepsOnlySubsectionsWithNonCompliance() {
        let section = makeSection(id: 1, applicable: true, statuses: [.notCompliant])
        let cleanSubsection = Subsection(name: "Clean")
        let okReq = Requirement(text: "Fine")
        okReq.complianceStatus = .compliant
        cleanSubsection.requirements = [okReq]
        section.subsections.append(cleanSubsection)

        // Sections aren't valid standalone in SwiftData — attach to a graph.
        let assessment = makeAssessment()
        assessment.sections = [section]

        #expect(section.nonCompliantSubsections.map(\.name) == ["Sub 1"])
    }

    @Test func requirementFilterExcludesNilNotApplicableAndCompliant() {
        let assessment = makeAssessment()
        let section = makeSection(
            id: 1, applicable: true,
            statuses: [.compliant, .notCompliant, .notApplicable, nil, .notCompliant]
        )
        assessment.sections = [section]

        let flagged = section.subsections[0].nonCompliantRequirements
        #expect(flagged.map(\.text) == ["Req 1.1", "Req 1.4"])
        #expect(flagged.allSatisfy { $0.complianceStatus == .notCompliant })
    }
}
