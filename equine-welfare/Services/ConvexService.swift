import Foundation
import ConvexMobile

@Observable
class ConvexService {
    static let shared = ConvexService()

    private let client: ConvexClientWithAuth<String>

    private init() {
        self.client = ConvexClientWithAuth(
            deploymentUrl: ConvexConfig.deploymentURL,
            authProvider: ClerkAuthProvider()
        )
    }

    /// Mints a fresh Convex JWT from the Clerk session and hands it to the
    /// client. Clerk template tokens are short-lived, so this is called at
    /// sync start and again between upload batches; the token is cached by
    /// Clerk, so refreshes are cheap unless it's actually near expiry.
    private func refreshAuth() async throws {
        if case .failure(let error) = await client.loginFromCache() {
            throw error
        }
    }

    // MARK: - Sync Assessment

    func syncAssessment(_ assessment: Assessment, progressHandler: ((String, Double) -> Void)? = nil) async throws {
        try await refreshAuth()

        progressHandler?("Preparing assessment data...", 0.1)

        // Prepare assessment data as JSON string
        let assessmentDict: [String: Any] = [
            "externalId": assessment.id.uuidString,
            "vetName": assessment.vetName,
            "farmName": assessment.farmName,
            "visitDate": assessment.visitDate.timeIntervalSince1970 * 1000,
            "isComplete": assessment.isComplete,
            "sideNotes": assessment.sideNotes ?? ""
        ]

        progressHandler?("Preparing horse data...", 0.2)

        // Prepare horses
        var horsesArray: [[String: Any]] = []
        for horse in assessment.horses {
            let horseDict: [String: Any] = [
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
            ]
            horsesArray.append(horseDict)
        }

        progressHandler?("Preparing section data...", 0.3)

        // Prepare sections (only applicable ones)
        var sectionsArray: [[String: Any]] = []
        for section in assessment.sections where section.isApplicable {
            var subsectionsArray: [[String: Any]] = []

            for subsection in section.subsections {
                var requirementsArray: [[String: Any]] = []

                for req in subsection.requirements {
                    let reqDict: [String: Any] = [
                        "text": req.text,
                        "complianceStatus": req.complianceStatus?.rawValue ?? "",
                        "nonComplianceReason": req.nonComplianceReason ?? ""
                    ]
                    requirementsArray.append(reqDict)
                }

                let subsectionDict: [String: Any] = [
                    "name": subsection.name,
                    "requirements": requirementsArray
                ]
                subsectionsArray.append(subsectionDict)
            }

            let sectionDict: [String: Any] = [
                "sectionNumber": section.id,
                "title": section.title,
                "isApplicable": section.isApplicable,
                "infoIconClicks": section.infoIconClicks,
                "subsections": subsectionsArray
            ]
            sectionsArray.append(sectionDict)
        }

        progressHandler?("Syncing to Convex...", 0.5)

        // Convert nested data to JSON strings for Convex
        let assessmentJson = try jsonString(from: assessmentDict)
        let horsesJson = try jsonString(from: horsesArray)
        let sectionsJson = try jsonString(from: sectionsArray)

        // Call mutation with JSON strings
        try await client.mutation("assessments:syncAssessment", with: [
            "assessmentJson": assessmentJson,
            "horsesJson": horsesJson,
            "sectionsJson": sectionsJson
        ])

        // MARK: - Upload horse photos (progress 0.6 to 0.9)

        let horses = assessment.horses
        let totalHorses = horses.count

        for (horseIndex, horse) in horses.enumerated() {
            try await refreshAuth()

            let horseId = horse.uuid.uuidString
            let horseProgress = 0.6 + (0.3 * Double(horseIndex) / Double(max(totalHorses, 1)))
            progressHandler?("Uploading photos for \(horse.name)...", horseProgress)

            // Collect all (attachment, parentType) pairs for this horse
            var photoUploads: [(MediaAttachment, String)] = []

            if let photo = horse.photoData {
                photoUploads.append((photo, "horse_photo"))
            }
            if let front = horse.frontPhotoData {
                photoUploads.append((front, "horse_front"))
            }
            if let right = horse.rightPhotoData {
                photoUploads.append((right, "horse_right"))
            }
            if let back = horse.backPhotoData {
                photoUploads.append((back, "horse_back"))
            }
            if let left = horse.leftPhotoData {
                photoUploads.append((left, "horse_left"))
            }
            for abnormal in horse.abnormalPhotosData {
                photoUploads.append((abnormal, "horse_abnormal"))
            }

            for (attachment, parentType) in photoUploads {
                try await uploadMedia(
                    data: attachment.data,
                    externalId: attachment.id.uuidString,
                    parentType: parentType,
                    parentId: horseId,
                    mediaType: attachment.mediaType.rawValue
                )
            }
        }

        // MARK: - Upload requirement media (progress 0.9 to 0.95)

        progressHandler?("Uploading requirement media...", 0.9)
        try await refreshAuth()

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
                            mediaType: attachment.mediaType.rawValue
                        )
                    }
                }
            }
        }

        progressHandler?("Sync complete!", 1.0)
    }

    private func jsonString(from value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        guard let string = String(data: data, encoding: .utf8) else {
            throw ConvexError.syncFailed
        }
        return string
    }

    // MARK: - Upload Media

    func uploadMedia(data: Data, externalId: String, parentType: String, parentId: String, mediaType: String) async throws {
        // Get upload URL
        let uploadUrl: String = try await client.mutation("files:generateUploadUrl", with: [:])

        // Upload file
        var request = URLRequest(url: URL(string: uploadUrl)!)
        request.httpMethod = "POST"
        request.setValue(mediaType == "image" ? "image/jpeg" : "video/mp4", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ConvexError.uploadFailed
        }

        // Parse storage ID from response
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let storageId = json["storageId"] as? String else {
            throw ConvexError.uploadFailed
        }

        // Save file reference
        try await client.mutation("files:saveFile", with: [
            "storageId": storageId,
            "externalId": externalId,
            "parentType": parentType,
            "parentId": parentId,
            "mediaType": mediaType,
            "creationDate": Date().timeIntervalSince1970 * 1000
        ])
    }
}

enum ConvexError: LocalizedError {
    case uploadFailed
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .uploadFailed:
            return "Failed to upload media file"
        case .syncFailed:
            return "Failed to sync assessment"
        }
    }
}
