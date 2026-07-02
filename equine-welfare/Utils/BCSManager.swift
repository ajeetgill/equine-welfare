import Foundation
import SwiftUI

// This will serve as the data model for BCS body parts in the view
struct BCSBodyPart: Identifiable {
    var id: String { name }
    let name: String
    let descriptions: [String]
}

// Codable structure to handle single-string and array descriptions
struct BCSBodyPartDescription: Codable {
    let description: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringArray = try? container.decode([String].self) {
            self.description = stringArray
        } else if let singleString = try? container.decode(String.self) {
            self.description = [singleString]
        } else {
            self.description = []
        }
    }

    init(description: [String]) {
        self.description = description
    }
}

// Main data structure for BCS
struct BCSData: Codable {
    let score: Int
    let photo: String
    let bodyParts: [String: BCSBodyPartDescription]

    enum CodingKeys: String, CodingKey {
        case score, photo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decode(Int.self, forKey: .score)
        photo = try container.decode(String.self, forKey: .photo)

        // Decode dynamic body part keys
        let allKeys = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var tempBodyParts = [String: BCSBodyPartDescription]()

        for key in allKeys.allKeys {
            if key.stringValue == "score" || key.stringValue == "photo" {
                continue
            }

            // First get the nested container for this body part
            if let nestedContainer = try? allKeys.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: key) {
                // Then get the description from within that container
                if let description = try? nestedContainer.decode([String].self, forKey: DynamicCodingKeys(stringValue: "description")) {
                    let bodyPartDesc = BCSBodyPartDescription(description: description)
                    tempBodyParts[key.stringValue] = bodyPartDesc
                } else if let description = try? nestedContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: "description")) {
                    let bodyPartDesc = BCSBodyPartDescription(description: [description])
                    tempBodyParts[key.stringValue] = bodyPartDesc
                }
            }
        }

        self.bodyParts = tempBodyParts
    }
}

// Helper for dynamic keys
struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    init(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { return nil }
    init?(intValue: Int) { return nil }
}

/// Loads and serves Body Condition Score reference data.
///
/// A single implementation backs both species: `BCSManager.shared` for horses
/// and `BCSManager.donkey` for donkeys. They differ only in which JSON file
/// they load and the display order of body parts.
final class BCSManager {
    /// Horse BCS reference data (`BCS.json`).
    static let shared = BCSManager(
        resource: "BCS",
        bodyPartOrder: [
            "WHOLE BODY",
            "NECK",
            "WITHERS",
            "BACK",
            "TAIL HEAD",
            "RIBS",
            "SHOULDER"
        ]
    )

    /// Donkey BCS reference data (`BCS-Donkey.json`).
    static let donkey = BCSManager(
        resource: "BCS-Donkey",
        bodyPartOrder: [
            "NECK AND SHOULDERS",
            "WITHERS",
            "RIBS AND BELLY",
            "BACK AND LOINS",
            "HINDQUARTERS"
        ]
    )

    private let resource: String
    private let bodyPartOrder: [String]
    private var bcsScores: [String: BCSData] = [:]

    init(resource: String, bodyPartOrder: [String]) {
        self.resource = resource
        self.bodyPartOrder = bodyPartOrder
        loadBCSData()
    }

    private func loadBCSData() {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ Failed to load \(resource).json file")
            return
        }

        do {
            let decoder = JSONDecoder()
            bcsScores = try decoder.decode([String: BCSData].self, from: data)
        } catch {
            print("❌ Error decoding BCS data from \(resource).json: \(error)")
        }
    }

    func getBCSImage(for score: Int) -> Image {
        let scoreKey = "BCS \(score)"

        guard let data = bcsScores[scoreKey],
              let uiImage = UIImage(named: data.photo) else {
            print("⚠️ Failed to load image for BCS \(score), image name: \(bcsScores[scoreKey]?.photo ?? "unknown")")
            return Image(systemName: "photo")
        }

        return Image(uiImage: uiImage)
    }

    func getBCSData(for score: Int) -> [BCSBodyPart]? {
        let scoreKey = "BCS \(score)"

        guard let data = bcsScores[scoreKey] else {
            print("⚠️ No BCS data found for score \(score) in \(resource).json")
            return nil
        }

        // Convert the dictionary to an array of BCSBodyPart
        var bodyParts = data.bodyParts.map { name, description in
            BCSBodyPart(name: name, descriptions: description.description)
        }

        // Sort the body parts according to the defined order
        bodyParts.sort { part1, part2 in
            let index1 = bodyPartOrder.firstIndex(of: part1.name) ?? Int.max
            let index2 = bodyPartOrder.firstIndex(of: part2.name) ?? Int.max
            return index1 < index2
        }

        return bodyParts
    }

    func getDescription(for score: Int, bodyPart: String) -> [String] {
        let scoreKey = "BCS \(score)"

        guard let data = bcsScores[scoreKey],
              let bodyPartDescription = data.bodyParts[bodyPart] else {
            return []
        }

        return bodyPartDescription.description
    }

    func getAllBodyParts(for score: Int) -> [String] {
        let scoreKey = "BCS \(score)"

        guard let data = bcsScores[scoreKey] else {
            return []
        }

        // Return body parts in the specified order
        return bodyPartOrder.filter { data.bodyParts.keys.contains($0) }
    }
}
