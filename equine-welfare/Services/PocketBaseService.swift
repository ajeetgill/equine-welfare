import Foundation

enum PocketBaseError: LocalizedError {
    case notSignedIn
    case server(String)
    case uploadFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in required to sync. Please sign in and try again."
        case .server(let message):
            return message
        case .uploadFailed:
            return "Failed to upload media file"
        case .invalidResponse:
            return "Unexpected response from the server"
        }
    }
}

@Observable
final class PocketBaseService {
    static let shared = PocketBaseService()

    private(set) var isSignedIn: Bool
    private(set) var userEmail: String?

    private init() {
        isSignedIn = KeychainStore.token != nil
        userEmail = KeychainStore.email
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        var request = URLRequest(url: PocketBaseConfig.baseURL.appending(path: "api/collections/users/auth-with-password"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["identity": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PocketBaseError.invalidResponse }
        guard http.statusCode == 200 else {
            throw PocketBaseError.server(Self.serverMessage(from: data) ?? "Sign-in failed. Check your email and password.")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String,
              let record = json["record"] as? [String: Any] else {
            throw PocketBaseError.invalidResponse
        }
        KeychainStore.token = token
        KeychainStore.email = record["email"] as? String ?? email
        isSignedIn = true
        userEmail = KeychainStore.email
    }

    func signOut() {
        // PocketBase tokens are stateless — signing out is purely local.
        KeychainStore.token = nil
        KeychainStore.email = nil
        isSignedIn = false
        userEmail = nil
    }

    /// Validates the stored token and rotates it. A 401/403 means the token
    /// expired or the user was deleted — clear local auth so the sign-in
    /// sheet is shown again.
    private func refreshAuth() async throws {
        guard let token = KeychainStore.token else { throw PocketBaseError.notSignedIn }
        var request = URLRequest(url: PocketBaseConfig.baseURL.appending(path: "api/collections/users/auth-refresh"))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PocketBaseError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 {
            signOut()
            throw PocketBaseError.notSignedIn
        }
        guard http.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["token"] as? String else {
            throw PocketBaseError.invalidResponse
        }
        KeychainStore.token = newToken
    }

    // MARK: - Sync Assessment

    func syncAssessment(_ assessment: Assessment, progressHandler: ((String, Double) -> Void)? = nil) async throws {
        try await refreshAuth()

        progressHandler?("Preparing assessment data...", 0.1)

        let assessmentDict: [String: Any] = [
            "externalId": assessment.id.uuidString,
            "vetName": assessment.vetName,
            "farmName": assessment.farmName,
            "visitDate": assessment.visitDate.timeIntervalSince1970 * 1000,
            "isComplete": assessment.isComplete,
            "sideNotes": assessment.sideNotes ?? ""
        ]

        progressHandler?("Preparing horse data...", 0.2)

        var horsesArray: [[String: Any]] = []
        for horse in assessment.horses {
            horsesArray.append([
                "externalId": horse.uuid.uuidString,
                "name": horse.name,
                "age": horse.age,
                "color": horse.color,
                "sex": horse.sex,
                "breed": horse.breed,
                "otherBreed": horse.otherBreed ?? "",
                "timeOnFarm": horse.timeOnFarm,
                "bcsScore": horse.bcsScore,
                "notes": horse.notes ?? "",
                "ageUnit": horse.ageUnit.rawValue,
                "timeUnit": horse.timeUnit.rawValue,
                "isHorse": horse.isHorse
            ])
        }

        progressHandler?("Preparing section data...", 0.3)

        var sectionsArray: [[String: Any]] = []
        for section in assessment.sections where section.isApplicable {
            var subsectionsArray: [[String: Any]] = []
            for subsection in section.subsections {
                var requirementsArray: [[String: Any]] = []
                for req in subsection.requirements {
                    requirementsArray.append([
                        "text": req.text,
                        "complianceStatus": req.complianceStatus?.rawValue ?? "",
                        "nonComplianceReason": req.nonComplianceReason ?? ""
                    ])
                }
                subsectionsArray.append([
                    "name": subsection.name,
                    "requirements": requirementsArray
                ])
            }
            sectionsArray.append([
                "sectionNumber": section.id,
                "title": section.title,
                "isApplicable": section.isApplicable,
                "infoIconClicks": section.infoIconClicks,
                "subsections": subsectionsArray
            ])
        }

        progressHandler?("Syncing to server...", 0.5)

        var request = URLRequest(url: PocketBaseConfig.baseURL.appending(path: "api/equine/sync-assessment"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(KeychainStore.token, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "assessment": assessmentDict,
            "horses": horsesArray,
            "sections": sectionsArray
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PocketBaseError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 {
            signOut()
            throw PocketBaseError.notSignedIn
        }
        guard http.statusCode == 200 else {
            throw PocketBaseError.server(Self.serverMessage(from: data) ?? "Sync failed. Please try again later.")
        }

        // MARK: Upload horse photos (progress 0.6 to 0.9)

        let assessmentExternalId = assessment.id.uuidString
        let horses = assessment.horses
        let totalHorses = horses.count

        for (horseIndex, horse) in horses.enumerated() {
            let horseId = horse.uuid.uuidString
            let horseProgress = 0.6 + (0.3 * Double(horseIndex) / Double(max(totalHorses, 1)))
            progressHandler?("Uploading photos for \(horse.name)...", horseProgress)

            var photoUploads: [(MediaAttachment, String)] = []
            if let photo = horse.photoData { photoUploads.append((photo, "horse_photo")) }
            if let front = horse.frontPhotoData { photoUploads.append((front, "horse_front")) }
            if let right = horse.rightPhotoData { photoUploads.append((right, "horse_right")) }
            if let back = horse.backPhotoData { photoUploads.append((back, "horse_back")) }
            if let left = horse.leftPhotoData { photoUploads.append((left, "horse_left")) }
            for abnormal in horse.abnormalPhotosData { photoUploads.append((abnormal, "horse_abnormal")) }

            for (attachment, parentType) in photoUploads {
                try await uploadMedia(
                    data: attachment.data,
                    externalId: attachment.id.uuidString,
                    parentType: parentType,
                    parentId: horseId,
                    assessmentExternalId: assessmentExternalId,
                    mediaType: attachment.mediaType.rawValue
                )
            }
        }

        // MARK: Upload requirement media (progress 0.9 to 0.95)

        progressHandler?("Uploading requirement media...", 0.9)

        for section in assessment.sections where section.isApplicable {
            for (subIdx, subsection) in section.subsections.enumerated() {
                for (reqIdx, requirement) in subsection.requirements.enumerated() {
                    guard !requirement.mediaAttachments.isEmpty else { continue }
                    let parentId = "\(assessment.id.uuidString)_\(section.id)_\(subIdx)_\(reqIdx)"
                    for attachment in requirement.mediaAttachments {
                        try await uploadMedia(
                            data: attachment.data,
                            externalId: attachment.id.uuidString,
                            parentType: "requirement",
                            parentId: parentId,
                            assessmentExternalId: assessmentExternalId,
                            mediaType: attachment.mediaType.rawValue
                        )
                    }
                }
            }
        }

        progressHandler?("Sync complete!", 1.0)
    }

    // MARK: - Upload Media

    /// One multipart record-create per file. A duplicate externalId means the
    /// file already landed in a previous (partial) sync — treated as success
    /// so retries stay idempotent, matching the old Convex saveFile dedupe.
    func uploadMedia(data: Data, externalId: String, parentType: String, parentId: String,
                     assessmentExternalId: String, mediaType: String) async throws {
        guard let token = KeychainStore.token else { throw PocketBaseError.notSignedIn }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: PocketBaseConfig.baseURL.appending(path: "api/collections/media_attachments/records"))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func addField(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }
        addField("externalId", externalId)
        addField("parentType", parentType)
        addField("parentId", parentId)
        addField("assessmentExternalId", assessmentExternalId)
        addField("mediaType", mediaType)
        addField("creationDate", ISO8601DateFormatter().string(from: Date()))

        let isImage = mediaType == "image"
        let filename = "\(externalId).\(isImage ? "jpg" : "mp4")"
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(isImage ? "image/jpeg" : "video/mp4")\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PocketBaseError.invalidResponse }
        switch http.statusCode {
        case 200:
            return
        case 400 where Self.isDuplicateExternalId(responseData):
            return
        case 401, 403:
            signOut()
            throw PocketBaseError.notSignedIn
        default:
            throw PocketBaseError.uploadFailed
        }
    }

    // MARK: - Response parsing

    private static func serverMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? String, !message.isEmpty else { return nil }
        return message
    }

    private static func isDuplicateExternalId(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fieldErrors = json["data"] as? [String: Any],
              let externalIdError = fieldErrors["externalId"] as? [String: Any],
              let code = externalIdError["code"] as? String else { return false }
        return code == "validation_not_unique"
    }
}
