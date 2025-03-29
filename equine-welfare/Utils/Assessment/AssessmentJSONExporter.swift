import Foundation
import SwiftData

/// Service to export Assessment data to JSON format
class AssessmentJSONExporter {
    
    /// Convert an Assessment to a JSON object focusing on non-compliant items
    /// - Parameter assessment: The assessment to convert
    /// - Returns: A dictionary representation that can be converted to JSON
    static func generateJSONObject(from assessment: Assessment) -> [String: Any] {
        // Create main structure
        var jsonObject: [String: Any] = [:]
        
        // Add metadata
        jsonObject["metadata"] = [
            "id": assessment.id.uuidString,
            "vetName": assessment.vetName,
            "farmName": assessment.farmName,
            "visitDate": assessment.formattedDate,
            "displayName": assessment.displayName
        ]
        
        // Add side notes if available
        if let sideNotes = assessment.sideNotes, !sideNotes.isEmpty {
            jsonObject["sideNotes"] = sideNotes
        }
        
        // Get non-compliant sections
        let nonCompliantSections = assessment.sections
            .filter { section in
                section.isApplicable && section.subsections.contains { subsection in
                    subsection.requirements.contains { requirement in
                        requirement.complianceStatus == .notCompliant
                    }
                }
            }
            .sorted(by: { $0.id < $1.id })
        
        // Process sections
        var sectionsArray: [[String: Any]] = []
        
        for section in nonCompliantSections {
            var sectionDict: [String: Any] = [
                "id": section.id,
                "title": section.title
            ]
            
            // Get non-compliant subsections
            let nonCompliantSubsections = section.subsections.filter { subsection in
                subsection.requirements.contains { requirement in
                    requirement.complianceStatus == .notCompliant
                }
            }
            
            // Process subsections
            var subsectionsArray: [[String: Any]] = []
            
            for subsection in nonCompliantSubsections {
                var subsectionDict: [String: Any] = [
                    "name": subsection.name
                ]
                
                // Get non-compliant requirements
                let nonCompliantRequirements = subsection.requirements.filter { requirement in
                    requirement.complianceStatus == .notCompliant
                }
                
                // Process requirements
                var requirementsArray: [[String: Any]] = []
                
                for requirement in nonCompliantRequirements {
                    var requirementDict: [String: Any] = [
                        "text": requirement.text,
                        "complianceStatus": requirement.complianceStatus?.rawValue ?? "Unknown"
                    ]
                    
                    // Add reason for non-compliance if available
                    if let reason = requirement.nonComplianceReason, !reason.isEmpty {
                        requirementDict["findings"] = reason
                    }
                    
                    requirementsArray.append(requirementDict)
                }
                
                subsectionDict["requirements"] = requirementsArray
                subsectionsArray.append(subsectionDict)
            }
            
            sectionDict["subsections"] = subsectionsArray
            sectionsArray.append(sectionDict)
        }
        
        // Add sections to the non-compliant findings
        jsonObject["nonCompliantFindings"] = ["sections": sectionsArray]
        
        return jsonObject
    }
    
    /// Convert an Assessment to a JSON string
    /// - Parameter assessment: The assessment to convert
    /// - Returns: A JSON string or nil if conversion fails
    static func generateJSON(from assessment: Assessment) -> String? {
        let jsonObject = generateJSONObject(from: assessment)
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error converting to JSON: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Save Assessment as a JSON file
    /// - Parameters:
    ///   - assessment: The assessment to save
    ///   - directory: The directory to save to (defaults to temporary directory)
    /// - Returns: URL to the saved file, or nil if saving fails
    static func saveAsJSON(assessment: Assessment, to directory: URL? = nil) -> URL? {
        guard let jsonString = generateJSON(from: assessment) else {
            return nil
        }
        
        // Determine directory - use provided one or temp directory
        let fileDirectory = directory ?? FileManager.default.temporaryDirectory
        
        // Create sanitized filename
        let fileName = "\(assessment.displayName).json"
        let fileURL = fileDirectory.appendingPathComponent(fileName)
        
        do {
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving JSON file: \(error.localizedDescription)")
            return nil
        }
    }
} 