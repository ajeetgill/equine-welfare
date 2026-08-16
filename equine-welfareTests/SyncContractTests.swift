import Foundation
import SwiftData
import Testing
@testable import Horse_C_O_P

/// Characterization tests for the sync pipeline in PocketBaseService.
///
/// They pin down the WIRE CONTRACT (the JSON payload sent to
/// /api/equine/sync-assessment, the multipart upload format, auth/error
/// handling) — not internal structure. The upcoming separation-of-concerns
/// refactor of the service must keep all of these green: as long as
/// `syncAssessment`/`signIn` still exist and send the same bytes, they pass.
///
/// Serialized because StubURLProtocol state and the Keychain are global.
@Suite(.serialized)
final class SyncContractTests {
    private let savedToken: String?
    private let savedEmail: String?
    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        savedToken = KeychainStore.token
        savedEmail = KeychainStore.email
        URLProtocol.registerClass(StubURLProtocol.self)
        StubURLProtocol.reset()
        KeychainStore.token = "stored-token"
        container = try ModelContainer(
            for: Assessment.self, Section.self, Subsection.self,
            Requirement.self, Horse.self, MediaAttachment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    deinit {
        KeychainStore.token = savedToken
        KeychainStore.email = savedEmail
        URLProtocol.unregisterClass(StubURLProtocol.self)
        StubURLProtocol.reset()
    }

    // MARK: - Fixtures

    private func stubHappyPath() {
        StubURLProtocol.stub(pathSuffix: "auth-refresh", status: 200,
                             jsonBody: #"{"token":"rotated-token"}"#)
        StubURLProtocol.stub(pathSuffix: "sync-assessment", status: 200, jsonBody: "{}")
        StubURLProtocol.stub(pathSuffix: "media_attachments/records", status: 200, jsonBody: "{}")
    }

    /// Section 1 (applicable): "Shelter" [compliant, notCompliant+reason(+photo)],
    ///                         "Ventilation" [unevaluated]
    /// Section 2 (NOT applicable): one notCompliant requirement — must be excluded
    /// Horse "Bella": main + left photo, one abnormal video (when withMedia)
    private func makeFixtureAssessment(withMedia: Bool) -> Assessment {
        let assessment = Assessment(
            vetName: "Dr. Jane Smith",
            farmName: "Green Acres",
            visitDate: Date(timeIntervalSince1970: 1_750_000_000)
        )
        context.insert(assessment)

        let housing = Section(id: 1, title: "Housing", isApplicable: true)
        let shelter = Subsection(name: "Shelter")
        let reqOK = Requirement(text: "Shelter available")
        reqOK.complianceStatus = .compliant
        let reqBad = Requirement(text: "Paddock drainage adequate")
        reqBad.complianceStatus = .notCompliant
        reqBad.nonComplianceReason = "Muddy paddock"
        if withMedia {
            reqBad.mediaAttachments.append(MediaAttachment(imageData: Data("req-photo".utf8)))
        }
        shelter.requirements = [reqOK, reqBad]
        let ventilation = Subsection(name: "Ventilation")
        ventilation.requirements = [Requirement(text: "Airflow acceptable")]
        housing.subsections = [shelter, ventilation]

        let feed = Section(id: 2, title: "Feed and Water", isApplicable: false)
        let feedSub = Subsection(name: "Feed quality")
        let feedReq = Requirement(text: "Feed stored properly")
        feedReq.complianceStatus = .notCompliant
        feedSub.requirements = [feedReq]
        feed.subsections = [feedSub]

        assessment.sections = [housing, feed]

        let horse = Horse(
            name: "Bella", age: 7, color: "Bay", sex: "Mare", breed: "Other",
            timeOnFarm: 24, bcsScore: 3.5, ageUnit: .years, timeUnit: .months
        )
        if withMedia {
            horse.photoData = MediaAttachment(imageData: Data("main-photo".utf8))
            horse.leftPhotoData = MediaAttachment(imageData: Data("left-photo".utf8))
            horse.abnormalPhotosData = [MediaAttachment(videoData: Data("abnormal-video".utf8))]
        }
        assessment.horses = [horse]
        return assessment
    }

    private func multipartValue(_ field: String, in body: Data) -> String? {
        let text = String(decoding: body, as: UTF8.self)
        guard let range = text.range(of: "name=\"\(field)\"\r\n\r\n") else { return nil }
        return text[range.upperBound...].components(separatedBy: "\r\n").first
    }

    // MARK: - Payload contract

    @Test func syncPayloadMatchesServerContract() async throws {
        stubHappyPath()
        let assessment = makeFixtureAssessment(withMedia: false)

        try await PocketBaseService.shared.syncAssessment(assessment)

        let syncRequests = StubURLProtocol.recorded(pathSuffix: "sync-assessment")
        #expect(syncRequests.count == 1)
        let request = try #require(syncRequests.first)
        #expect(request.method == "POST")
        #expect(request.headers["Authorization"] == "rotated-token")

        let payload = try #require(
            try JSONSerialization.jsonObject(with: request.body) as? [String: Any])

        let a = try #require(payload["assessment"] as? [String: Any])
        #expect(a["externalId"] as? String == assessment.id.uuidString)
        #expect(a["vetName"] as? String == "Dr.-Jane-Smith")
        #expect(a["farmName"] as? String == "Green-Acres")
        #expect(a["visitDate"] as? Double == 1_750_000_000_000)
        #expect(a["isComplete"] as? Bool == false)
        #expect(a["sideNotes"] as? String == "")
        #expect(a["copVersion"] as? String == "2013")

        let horses = try #require(payload["horses"] as? [[String: Any]])
        #expect(horses.count == 1)
        let h = try #require(horses.first)
        #expect(h["externalId"] as? String == assessment.horses[0].uuid.uuidString)
        #expect(h["name"] as? String == "Bella")
        #expect(h["age"] as? Int == 7)
        #expect(h["breed"] as? String == "Other")
        #expect(h["otherBreed"] as? String == "")
        #expect(h["notes"] as? String == "")
        #expect(h["timeOnFarm"] as? Int == 24)
        #expect(h["bcsScore"] as? Double == 3.5)
        #expect(h["ageUnit"] as? String == "years")
        #expect(h["timeUnit"] as? String == "months")
        #expect(h["isHorse"] as? Bool == true)

        let sections = try #require(payload["sections"] as? [[String: Any]])
        #expect(sections.count == 1, "non-applicable sections must be excluded")
        let s = try #require(sections.first)
        #expect(s["sectionNumber"] as? Int == 1)
        #expect(s["title"] as? String == "Housing")
        #expect(s["isApplicable"] as? Bool == true)
        #expect(s["infoIconClicks"] as? Int == 0)

        let subsections = try #require(s["subsections"] as? [[String: Any]])
        #expect(subsections.map { $0["name"] as? String } == ["Shelter", "Ventilation"])

        let shelterReqs = try #require(subsections[0]["requirements"] as? [[String: Any]])
        #expect(shelterReqs[0]["complianceStatus"] as? String == "Compliant")
        #expect(shelterReqs[0]["nonComplianceReason"] as? String == "")
        #expect(shelterReqs[1]["text"] as? String == "Paddock drainage adequate")
        #expect(shelterReqs[1]["complianceStatus"] as? String == "Not Compliant")
        #expect(shelterReqs[1]["nonComplianceReason"] as? String == "Muddy paddock")

        let ventilationReqs = try #require(subsections[1]["requirements"] as? [[String: Any]])
        #expect(ventilationReqs[0]["complianceStatus"] as? String == "",
                "unevaluated requirement serializes as empty string")
    }

    @Test func syncRotatesTokenViaAuthRefresh() async throws {
        stubHappyPath()
        let assessment = makeFixtureAssessment(withMedia: false)

        try await PocketBaseService.shared.syncAssessment(assessment)

        let refreshes = StubURLProtocol.recorded(pathSuffix: "auth-refresh")
        #expect(refreshes.count == 1)
        #expect(refreshes.first?.headers["Authorization"] == "stored-token")
        #expect(KeychainStore.token == "rotated-token")
    }

    // MARK: - Media upload contract

    @Test func syncUploadsMediaAsMultipartInDocumentedOrder() async throws {
        stubHappyPath()
        let assessment = makeFixtureAssessment(withMedia: true)
        let horse = assessment.horses[0]

        try await PocketBaseService.shared.syncAssessment(assessment)

        let uploads = StubURLProtocol.recorded(pathSuffix: "media_attachments/records")
        #expect(uploads.map { multipartValue("parentType", in: $0.body) }
                == ["horse_photo", "horse_left", "horse_abnormal", "requirement"])

        // Horse photos: parented by horse uuid, tagged with the assessment.
        let first = try #require(uploads.first)
        #expect(first.headers["Content-Type"]?.hasPrefix("multipart/form-data; boundary=") == true)
        #expect(first.headers["Authorization"] == "rotated-token")
        #expect(multipartValue("parentId", in: first.body) == horse.uuid.uuidString)
        #expect(multipartValue("assessmentExternalId", in: first.body) == assessment.id.uuidString)
        #expect(multipartValue("mediaType", in: first.body) == "image")
        let photoId = try #require(horse.photoData?.id.uuidString)
        #expect(multipartValue("externalId", in: first.body) == photoId)
        let firstText = String(decoding: first.body, as: UTF8.self)
        #expect(firstText.contains("filename=\"\(photoId).jpg\""))
        #expect(firstText.contains("Content-Type: image/jpeg"))
        #expect(firstText.contains("main-photo"))

        // Videos keep their media type and extension.
        let video = uploads[2]
        #expect(multipartValue("mediaType", in: video.body) == "video")
        #expect(String(decoding: video.body, as: UTF8.self).contains(".mp4\""))

        // Requirement media: composite parentId assessmentId_sectionId_subIdx_reqIdx.
        // "Paddock drainage adequate" is section 1, subsection 0, requirement 1.
        let reqUpload = try #require(uploads.last)
        #expect(multipartValue("parentId", in: reqUpload.body)
                == "\(assessment.id.uuidString)_1_0_1")
        #expect(multipartValue("parentType", in: reqUpload.body) == "requirement")
    }

    @Test func duplicateExternalIdUploadIsTreatedAsSuccess() async throws {
        StubURLProtocol.stub(pathSuffix: "auth-refresh", status: 200,
                             jsonBody: #"{"token":"rotated-token"}"#)
        StubURLProtocol.stub(pathSuffix: "sync-assessment", status: 200, jsonBody: "{}")
        StubURLProtocol.stub(
            pathSuffix: "media_attachments/records", status: 400,
            jsonBody: #"{"data":{"externalId":{"code":"validation_not_unique","message":"Value must be unique."}}}"#
        )
        let assessment = makeFixtureAssessment(withMedia: true)

        // Re-syncing already-uploaded media must stay idempotent — no throw.
        try await PocketBaseService.shared.syncAssessment(assessment)
        #expect(StubURLProtocol.recorded(pathSuffix: "media_attachments/records").count == 4)
    }

    @Test func nonDuplicate400UploadThrowsUploadFailed() async throws {
        StubURLProtocol.stub(pathSuffix: "auth-refresh", status: 200,
                             jsonBody: #"{"token":"rotated-token"}"#)
        StubURLProtocol.stub(pathSuffix: "sync-assessment", status: 200, jsonBody: "{}")
        StubURLProtocol.stub(
            pathSuffix: "media_attachments/records", status: 400,
            jsonBody: #"{"data":{"file":{"code":"validation_invalid_mime_type"}}}"#
        )
        let assessment = makeFixtureAssessment(withMedia: true)

        do {
            try await PocketBaseService.shared.syncAssessment(assessment)
            Issue.record("expected uploadFailed to be thrown")
        } catch let error as PocketBaseError {
            guard case .uploadFailed = error else {
                Issue.record("expected .uploadFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - Auth failure handling

    @Test func syncWithoutStoredTokenThrowsNotSignedInWithoutNetworkCalls() async throws {
        stubHappyPath()
        KeychainStore.token = nil
        let assessment = makeFixtureAssessment(withMedia: false)

        do {
            try await PocketBaseService.shared.syncAssessment(assessment)
            Issue.record("expected notSignedIn to be thrown")
        } catch let error as PocketBaseError {
            guard case .notSignedIn = error else {
                Issue.record("expected .notSignedIn, got \(error)")
                return
            }
        }
        #expect(StubURLProtocol.recorded.isEmpty)
    }

    @Test func expiredTokenSignsOutAndThrowsNotSignedIn() async throws {
        StubURLProtocol.stub(pathSuffix: "auth-refresh", status: 401,
                             jsonBody: #"{"message":"The request requires valid record authorization token."}"#)
        let assessment = makeFixtureAssessment(withMedia: false)

        do {
            try await PocketBaseService.shared.syncAssessment(assessment)
            Issue.record("expected notSignedIn to be thrown")
        } catch let error as PocketBaseError {
            guard case .notSignedIn = error else {
                Issue.record("expected .notSignedIn, got \(error)")
                return
            }
        }
        #expect(KeychainStore.token == nil, "expired token must be cleared so sign-in is shown")
        #expect(PocketBaseService.shared.isSignedIn == false)
    }

    @Test func serverErrorMessageSurfacesInThrownError() async throws {
        StubURLProtocol.stub(pathSuffix: "auth-refresh", status: 200,
                             jsonBody: #"{"token":"rotated-token"}"#)
        StubURLProtocol.stub(pathSuffix: "sync-assessment", status: 500,
                             jsonBody: #"{"message":"Sync failed inside transaction."}"#)
        let assessment = makeFixtureAssessment(withMedia: false)

        do {
            try await PocketBaseService.shared.syncAssessment(assessment)
            Issue.record("expected server error to be thrown")
        } catch let error as PocketBaseError {
            guard case .server(let message) = error else {
                Issue.record("expected .server, got \(error)")
                return
            }
            #expect(message == "Sync failed inside transaction.")
        }
    }

    // MARK: - Sign-in

    @Test func signInStoresTokenAndEmailAndFlipsState() async throws {
        StubURLProtocol.stub(
            pathSuffix: "auth-with-password", status: 200,
            jsonBody: #"{"token":"fresh-token","record":{"email":"vet@example.com"}}"#
        )

        try await PocketBaseService.shared.signIn(email: "vet@example.com", password: "hunter22")

        #expect(KeychainStore.token == "fresh-token")
        #expect(KeychainStore.email == "vet@example.com")
        #expect(PocketBaseService.shared.isSignedIn == true)
        #expect(PocketBaseService.shared.userEmail == "vet@example.com")

        let request = try #require(StubURLProtocol.recorded(pathSuffix: "auth-with-password").first)
        let body = try #require(try JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body["identity"] as? String == "vet@example.com")
        #expect(body["password"] as? String == "hunter22")
    }

    @Test func signInFailureSurfacesServerMessage() async throws {
        StubURLProtocol.stub(pathSuffix: "auth-with-password", status: 400,
                             jsonBody: #"{"message":"Failed to authenticate."}"#)

        do {
            try await PocketBaseService.shared.signIn(email: "vet@example.com", password: "wrong")
            Issue.record("expected server error to be thrown")
        } catch let error as PocketBaseError {
            guard case .server(let message) = error else {
                Issue.record("expected .server, got \(error)")
                return
            }
            #expect(message == "Failed to authenticate.")
        }
    }
}
