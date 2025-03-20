import Foundation
import SwiftData

/// Parses the COP.json data and returns an array of `Section` objects.
func parseCOPJSON(data: Data) throws -> [Section] {
    // Decode the JSON into a dictionary.
    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
        throw NSError(domain: "Invalid JSON format", code: 0, userInfo: nil)
    }
    
    var sections: [Section] = []
    
    // Iterate through each section in the JSON.
    for (sectionKey, sectionContent) in json {
        // Expected format: "Section X - Title"
        let keyComponents = sectionKey.components(separatedBy: " - ")
        guard keyComponents.count >= 2 else { continue }
        
        // Extract section ID (as an Int) and title.
        let idString = keyComponents[0].replacingOccurrences(of: "Section", with: "").trimmingCharacters(in: .whitespaces)
        guard let sectionID = Int(idString) else { continue }
        let sectionTitle = keyComponents[1].trimmingCharacters(in: .whitespaces)
        
        let section = Section(id: sectionID, title: sectionTitle)
        
        // The section content is expected to be a dictionary.
        guard let contentDict = sectionContent as? [String: Any] else { continue }
        
        // If there is a top-level "Requirements" key, create a default subsection.
        if let requirementsDict = contentDict["Requirements"] as? [String: String] {
            let subsection = Subsection( name: sectionTitle)
            for (_, requirementText) in requirementsDict {
                let requirement = Requirement(text: requirementText)
                subsection.requirements.append(requirement)
            }
            section.subsections.append(subsection)
        }
        
        // If there are "Subsections", iterate and create each one.
        if let subsectionsDict = contentDict["Subsections"] as? [String: Any] {
            for (subKey, subContent) in subsectionsDict {
                let subsection = Subsection(name: subKey)
                if let subContentDict = subContent as? [String: Any],
                   let reqs = subContentDict["Requirements"] as? [String: String] {
                    for (_, requirementText) in reqs {
                        let requirement = Requirement(text: requirementText)
                        subsection.requirements.append(requirement)
                    }
                }
                section.subsections.append(subsection)
            }
        }
        
        sections.append(section)
    }
    
    return sections
}

// Helper extension for sorting subsection numbers
 extension String {
    /// Extracts dot-separated numeric components (e.g. "2.1.4" -> [2,1,4]).
    /// If the string can't be split into valid integers, returns an empty array.
    func numericComponents() -> [Int] {
        // Split on whitespace and take first part (e.g., "2.1.4" from "2.1.4 Pastures and Yards")
        let parts = self.trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
        
        // If the first part is something like "2.1.4", split by "."
        guard let numericPart = parts.first else { return [] }
        
        return numericPart
            .split(separator: ".")
            .compactMap { Int($0) }  // convert each to Int, discarding non-numeric
    }
}

class COPService {
    /// Loads and parses the COP.json file, returning an array of Section models.
    /// If there's an error loading or parsing the file, returns an empty array.
    static func loadSections() -> [Section] {
        // Attempt to locate the COP.json file in the bundle
        guard let url = Bundle.main.url(forResource: "COP", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Error: COP.json not found in bundle")
            return []
        }
        
        do {
            // Decode the JSON into a dictionary
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                print("Error: Invalid JSON format")
                return []
            }
            
            var sections: [Section] = []
            
            // Sort section keys (e.g. "Section 1 - Title")
            let sortedKeys = json.keys.sorted { key1, key2 in
                let num1 = Int(key1.split(separator: " ")[1]) ?? 0
                let num2 = Int(key2.split(separator: " ")[1]) ?? 0
                return num1 < num2
            }
            
            // Process each section
            for sectionKey in sortedKeys {
                let components = sectionKey.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
                guard components.count >= 2 else { continue }
                
                // Extract section number and title
                let sectionNumberString = components[0].replacingOccurrences(of: "Section", with: "").trimmingCharacters(in: .whitespaces)
                guard let sectionNumber = Int(sectionNumberString) else { continue }
                
                let sectionTitle = components[1]
                guard let sectionContent = json[sectionKey] as? [String: Any] else { continue }
                
                // Create the section
                let section = Section(id: sectionNumber, title: sectionTitle)
                
                // Handle direct requirements (like in Section 1)
                if let requirementsDict = sectionContent["Requirements"] as? [String: String] {
                    let subsection = Subsection(name: sectionTitle)
                    let sortedRequirements = requirementsDict.sorted { 
                        (Int($0.key) ?? 0) < (Int($1.key) ?? 0)
                    }
                    subsection.requirements = sortedRequirements.map { 
                        Requirement(text: $0.value)
                    }
                    section.subsections.append(subsection)
                }
                
                // Handle subsections (like in Section 2+)
                if let subsectionsDict = sectionContent["Subsections"] as? [String: Any] {
                    // Sort subsections using numericComponents
                    let sortedSubsectionKeys = subsectionsDict.keys.sorted { s1, s2 in
                        let comps1 = s1.numericComponents()
                        let comps2 = s2.numericComponents()
                        
                        // Compare components lexicographically
                        for i in 0..<min(comps1.count, comps2.count) {
                            if comps1[i] < comps2[i] { return true }
                            if comps1[i] > comps2[i] { return false }
                        }
                        // If all common components match, shorter array comes first
                        return comps1.count < comps2.count
                    }
                    
                    for subKey in sortedSubsectionKeys {
                        guard let subContent = subsectionsDict[subKey] as? [String: Any],
                              let requirements = subContent["Requirements"] as? [String: String] else {
                            continue
                        }
                        
                        let subsection = Subsection(name: subKey)
                        let sortedRequirements = requirements.sorted { 
                            (Int($0.key) ?? 0) < (Int($1.key) ?? 0)
                        }
                        subsection.requirements = sortedRequirements.map { 
                            Requirement(text: $0.value)
                        }
                        section.subsections.append(subsection)
                    }
                }
                
                sections.append(section)
            }
            
            return sections
            
        } catch {
            print("Error parsing COP.json: \(error)")
            return []
        }
    }
}
