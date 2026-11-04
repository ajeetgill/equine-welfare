import Foundation
import SwiftData
import Testing
@testable import Horse_C_O_P

/// Pins model-level values other layers depend on: the dashboard string-matches
/// ComplianceStatus raw values, filenames/exports use displayName, and the sync
/// payload carries the enum raw values verbatim.
struct ModelContractTests {
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

    @Test func assessmentInitTrimsAndDashesNames() {
        let assessment = Assessment(
            vetName: "  Dr. Jane Smith  ",
            farmName: " Green Acres ",
            visitDate: .now
        )
        context.insert(assessment)
        #expect(assessment.vetName == "Dr.-Jane-Smith")
        #expect(assessment.farmName == "Green-Acres")
        #expect(assessment.isComplete == false)
        #expect(assessment.sideNotes == nil)
    }

    @Test func displayNameIsDateVetFarmJoinedWithDashes() {
        let assessment = Assessment(
            vetName: "Dr. Jane Smith",
            farmName: "Green Acres",
            visitDate: Date(timeIntervalSince1970: 1_750_000_000)
        )
        context.insert(assessment)
        let name = assessment.displayName
        // Date part is locale-formatted (yyyy-MMM-dd); assert shape, not spelling.
        #expect(name.range(of: #"^\d{4}-\w{3}-\d{2}-"#, options: .regularExpression) != nil)
        #expect(name.hasSuffix("-Dr.-Jane-Smith-Green-Acres"))
    }

    @Test func newAssessmentIsStampedWithCurrentCOPEdition() {
        let assessment = Assessment(vetName: "V", farmName: "F", visitDate: .now)
        context.insert(assessment)
        #expect(COPEdition.current == "2013")
        #expect(assessment.copVersion == COPEdition.current)
    }

    @Test func complianceStatusRawValuesAreTheWireContract() {
        // The dashboard's docx generator and the sync payload both carry these
        // exact strings — changing them is a breaking, cross-platform change.
        #expect(ComplianceStatus.compliant.rawValue == "Compliant")
        #expect(ComplianceStatus.notCompliant.rawValue == "Not Compliant")
        #expect(ComplianceStatus.notApplicable.rawValue == "N/A")
        #expect(ComplianceStatus.allCases.count == 3)
    }

    @Test func mediaTypeFileMetadataMatchesUploadFormat() {
        #expect(MediaType.image.rawValue == "image")
        #expect(MediaType.image.fileExtension == "jpg")
        #expect(MediaType.image.mimeType == "image/jpeg")
        #expect(MediaType.video.rawValue == "video")
        #expect(MediaType.video.fileExtension == "mp4")
        #expect(MediaType.video.mimeType == "video/mp4")
    }

    @Test func ageAndTimeUnitRawValuesAreTheWireContract() {
        #expect(AgeUnit.allCases.map(\.rawValue) == ["years", "months", "weeks", "days"])
        #expect(TimeUnit.allCases.map(\.rawValue) == ["years", "months", "weeks", "days"])
    }

    @Test func mediaAttachmentInitializersSetTypeAndData() {
        let image = MediaAttachment(imageData: Data("img".utf8))
        let video = MediaAttachment(videoData: Data("vid".utf8))
        #expect(image.mediaType == .image)
        #expect(video.mediaType == .video)
        #expect(image.data == Data("img".utf8))
        #expect(image.id != video.id)
    }
}
