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

class BCSManager {
    static let shared = BCSManager()
    
    // Add this constant for ordering body parts
    private let bodyPartOrder = [
        "WHOLE BODY",
        "NECK",
        "WITHERS", 
        "BACK",
        "TAIL HEAD",
        "RIBS",
        "SHOULDER"
    ]
    
    private var bcsScores: [String: BCSData] = [:]
    
    // Changed from private to internal (default) so it can be accessed
    init() {
        loadBCSData()
    }
    
    private func loadBCSData() {
        guard let url = Bundle.main.url(forResource: "BCS", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ Failed to load BCS.json file")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            bcsScores = try decoder.decode([String: BCSData].self, from: data)
        } catch {
            print("❌ Error decoding BCS data: \(error)")
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
            print("⚠️ No BCS data found for score: \(score)")
            return nil
        }
        
        print("Found BCS data for score \(score)")
        print("Body parts count: \(data.bodyParts.count)")
        
        // List all the body part keys to verify
        print("Body parts: \(data.bodyParts.keys.joined(separator: ", "))")
        
        // Debug each body part's description data
        for (name, desc) in data.bodyParts {
            print("Body part: \(name), has \(desc.description.count) descriptions")
            print("  - Descriptions: \(desc.description.joined(separator: ", "))")
        }
        
        // Convert the dictionary to an array of BCSBodyPart 
        var bodyParts = data.bodyParts.map { name, description in
            let part = BCSBodyPart(name: name, descriptions: description.description)
            // Debug the created object
            print("Created BCSBodyPart: \(part.name) with \(part.descriptions.count) descriptions")
            return part
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