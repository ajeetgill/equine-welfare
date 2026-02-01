import Foundation
import ConvexMobile

@Observable
class ConvexService {
    static let shared = ConvexService()

    private let client: ConvexClient

    private init() {
        self.client = ConvexClient(deploymentUrl: ConvexConfig.deploymentURL)
    }

    // MARK: - Sync Assessment

    func syncAssessment(_ assessment: Assessment, progressHandler: ((String, Double) -> Void)? = nil) async throws {
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
