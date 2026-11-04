import Foundation
import SwiftData
import Testing
@testable import Horse_C_O_P

/// The COP-update story rests on one property: an assessment deep-copies the
/// reference data at creation and is never touched by it again. Shipping a
/// new COP.json edition must only affect assessments created afterwards —
/// these tests fail loudly if anyone ever makes existing assessments reload
/// or share reference data.
struct COPSnapshotTests {
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

    /// COP.json section order isn't guaranteed — always match by section id.
    private func section1(_ sections: [Section]) throws -> Section {
        try #require(sections.first { $0.id == 1 })
    }

    @Test func loadSectionsReturnsIndependentCopiesEachCall() throws {
        let first = COPService.loadSections()
        let second = COPService.loadSections()
        #expect(!first.isEmpty)

        let pristineTexts = try section1(second).subsections[0].requirements.map(\.text).sorted()

        // Vandalize the first load; the second and any later load must be immune.
        let mutated = try section1(first)
        mutated.subsections[0].requirements[0].text = "MUTATED"
        mutated.subsections[0].requirements.append(Requirement(text: "EXTRA"))

        #expect(try section1(second).subsections[0].requirements.map(\.text).sorted() == pristineTexts)
        #expect(try section1(COPService.loadSections()).subsections[0].requirements.map(\.text).sorted() == pristineTexts)
    }

    @Test func existingAssessmentsAreImmuneToLaterReferenceDataMutations() throws {
        let viewModelA = SectionSelectionViewModel(modelContext: context)
        let idA = viewModelA.createNewAssessment(vetName: "A", farmName: "FarmA", visitDate: .now)
        let assessmentA = try #require(try context.fetch(
            FetchDescriptor<Assessment>(predicate: #Predicate { $0.id == idA })).first)
        let sectionA = try section1(assessmentA.sections)
        let snapshotTexts = sectionA.subsections[0].requirements.map(\.text).sorted()
        #expect(!snapshotTexts.isEmpty)

        // A second assessment gets its own copies — not A's objects.
        let viewModelB = SectionSelectionViewModel(modelContext: context)
        let idB = viewModelB.createNewAssessment(vetName: "B", farmName: "FarmB", visitDate: .now)
        let assessmentB = try #require(try context.fetch(
            FetchDescriptor<Assessment>(predicate: #Predicate { $0.id == idB })).first)
        let sectionB = try section1(assessmentB.sections)
        #expect(ObjectIdentifier(sectionA) != ObjectIdentifier(sectionB),
                "assessments must not share Section instances")

        // Editing B (or hypothetically a new COP edition) must never reach A.
        sectionB.subsections[0].requirements[0].text = "MUTATED"
        sectionB.subsections[0].requirements.append(Requirement(text: "EXTRA"))

        #expect(sectionA.subsections[0].requirements.map(\.text).sorted() == snapshotTexts)
        #expect(try section1(COPService.loadSections()).subsections[0].requirements.map(\.text).sorted() == snapshotTexts,
                "reference data itself must stay pristine")
    }
}
