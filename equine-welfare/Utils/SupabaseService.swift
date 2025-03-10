//
//  Supabase.swift
//  test-supabase
//
//  Created by Ajeet Gill on 07/03/25.
//

import Foundation
import Supabase
import SwiftUI
import SwiftData
import Combine

/// Service class to handle all Supabase interactions
class SupabaseService {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = SupabaseService()
    
    /// Supabase client instance
    private let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://aknlkmbwbbnfxaoqljzd.supabase.co")!,
        supabaseKey:
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFrbmxrbWJ3YmJuZnhhb3FsanpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEzOTEyMTQsImV4cCI6MjA1Njk2NzIxNH0.kjZRF_JwWN9ovTahZFmGcj9h6XgIhApWTVCrAA6o8ZQ"
    )
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Public Methods
    
    /// Uploads an assessment to Supabase
    /// - Parameter assessment: The assessment to upload
    /// - Returns: A result with a success message or an error
    func uploadAssessment(_ assessment: Assessment) async -> Void {
        // First, print the assessment data for debugging
        // assessment.getNonCompliantSections().forEach{ section in
        //     print(section.title)
        // }
//        printAssessmentData(assessment.getNonCompliantSections())
        
        // do {
        //     // Convert assessment to a dictionary for upload
        //     let assessmentData = try convertAssessmentToDict(assessment)
            
        //     // Upload to Supabase
        //     let response = try await supabase.database
        //         .from("assessments")
        //         .insert(assessmentData)
        //         .execute()
            
        //     return .success("Assessment uploaded successfully")
        // } catch {
        //     print("Error uploading assessment: \(error.localizedDescription)")
        //     return .failure(error)
        // }
    }
    
    /// Uploads an RTF file to Supabase Storage
    /// - Parameters:
    ///   - fileURL: The local URL of the RTF file to upload
    ///   - assessment: The assessment associated with the file
    /// - Returns: A result with a success message or an error
    func uploadRTFDocument(fileURL: URL, assessment: Assessment) async -> Result<String, Error> {
        do {
            // Create a sanitized folder name based on assessment name
            let sanitizedFolderName = assessment.displayName.replacingOccurrences(of: "/", with: "-")
            
            // Create a file name using the assessment name and date
            let fileName = "\(sanitizedFolderName).rtf"
            
            // Full path in storage will be: assessments/{sanitizedFolderName}/{fileName}
            let storagePath = "assessments/\(sanitizedFolderName)/\(fileName)"
            
            // Read the file data
            let fileData = try Data(contentsOf: fileURL)
            
            // Upload to Supabase Storage
            let response = try await supabase.storage
                .from("assessments")
                .upload(
                    path: "\(sanitizedFolderName)/\(fileName)",
                    file: fileData,
                    options: FileOptions(contentType: "application/rtf")
                )
            
            // Generate a public URL for the uploaded file
            let publicURL = try await supabase.storage
                .from("assessments")
                .createSignedURL(path: "\(sanitizedFolderName)/\(fileName)", expiresIn: 3600 * 24 * 7) // 7 days expiry
            
            return .success("Assessment document uploaded successfully: \(publicURL)")
        } catch {
            print("Error uploading RTF document: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    /// Uploads all media attachments from an assessment to Supabase Storage
    /// - Parameters:
    ///   - assessment: The assessment containing media attachments
    ///   - progressHandler: Optional closure to handle upload progress updates (0.0 to 1.0)
    /// - Returns: A result containing the number of successfully uploaded files or an error
    func uploadAssessmentMedia(assessment: Assessment, progressHandler: ((Double) -> Void)? = nil) async -> Result<Int, Error> {
        // Create a sanitized folder name based on assessment name (same naming convention as RTF upload)
        let sanitizedFolderName = assessment.displayName.replacingOccurrences(of: "/", with: "-")
        
        // Collect all media attachments from the assessment
        var allMediaAttachments: [MediaAttachment] = []
        
        // Traverse the assessment structure to find all media attachments
        for section in assessment.sections where section.isApplicable {
            for subsection in section.subsections {
                for requirement in subsection.requirements {
                    allMediaAttachments.append(contentsOf: requirement.mediaAttachments)
                }
            }
        }
        
        // If no media attachments found, return early
        if allMediaAttachments.isEmpty {
            return .success(0)
        }
        
        // Track upload progress
        var successCount = 0
        var errorCount = 0
        let totalCount = allMediaAttachments.count
        
        // Create a task group for concurrent uploads
        do {
            // Use a simple approach with a loop instead of task groups for better control
            for (index, attachment) in allMediaAttachments.enumerated() {
                do {
                    // Only process attachments that have imageData
                    guard let imageData = attachment.data as? Data else {
                        errorCount += 1
                        continue
                    }
                    
                    // Create a unique filename based on attachment ID and timestamp
                    let fileName = "media_\(attachment.id)_\(Int(Date().timeIntervalSince1970)).jpg"
                    let path = "\(sanitizedFolderName)/media/\(fileName)"
                    
                    // Upload the file to Supabase
                    _ = try await supabase.storage
                        .from("assessments")
                        .upload(
                            path: path,
                            file: imageData,
                            options: FileOptions(contentType: "image/jpeg")
                        )
                    
                    // Increment success counter
                    successCount += 1
                    
                    // Report progress
                    let progress = Double(index + 1) / Double(totalCount)
                    progressHandler?(progress)
                    
                } catch {
                    print("Error uploading media attachment: \(error.localizedDescription)")
                    errorCount += 1
                }
            }
            
            // If all failed, throw an error
            if errorCount == totalCount && totalCount > 0 {
                return .failure(NSError(domain: "SupabaseService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to upload all media attachments"]))
            }
            
            return .success(successCount)
        } catch {
            return .failure(error)
        }
    }
    
    /// Prints the assessment data for debugging purposes
    /// - Parameter assessment: The assessment to print
    func printAssessmentData(_ assessment: Assessment) {
        print("===== ASSESSMENT DATA =====")
        print("ID: \(assessment.id)")
        print("Vet Name: \(assessment.vetName)")
        print("Farm Name: \(assessment.farmName)")
        print("Visit Date: \(assessment.formattedDate)")
        print("Is Complete: \(assessment.isComplete)")
        
        print("\nSections (\(assessment.sections.count)):")
        for (index, section) in assessment.sections.enumerated() {
            print("  Section \(index + 1): \(section.title)")
            print("  Is Applicable: \(section.isApplicable)")
            
            print("  Subsections (\(section.subsections.count)):")
            for (subIndex, subsection) in section.subsections.enumerated() {
                print("    Subsection \(subIndex + 1): \(subsection.name)")
                
                print("    Requirements (\(subsection.requirements.count)):")
                for (reqIndex, requirement) in subsection.requirements.enumerated() {
                    print("      Requirement \(reqIndex + 1): \(requirement.text)")
                    print("      Status: \(requirement.complianceStatus?.rawValue ?? "Not Evaluated")")
                    if let reason = requirement.nonComplianceReason, !reason.isEmpty {
                        print("      Reason: \(reason)")
                    }
                }
            }
        }
        
        print("\nHorses (\(assessment.horses.count)):")
        for (index, horse) in assessment.horses.enumerated() {
            print("  Horse \(index + 1): \(horse.name)")
            // Add more horse details as needed
        }
        
        print("===== END ASSESSMENT DATA =====")
    }
    
    // MARK: - Private Helper Methods
    
    /// Converts an assessment to a dictionary for Supabase upload
    /// - Parameter assessment: The assessment to convert
    /// - Returns: A dictionary representation of the assessment
    private func convertAssessmentToDict(_ assessment: Assessment) throws -> [String: Any] {
        // Basic assessment data
        var assessmentDict: [String: Any] = [
            "id": assessment.id.uuidString,
            "vet_name": assessment.vetName,
            "farm_name": assessment.farmName,
            "visit_date": ISO8601DateFormatter().string(from: assessment.visitDate),
            "is_complete": assessment.isComplete
        ]
        
        // Convert sections to JSON
        let sectionsData = try JSONSerialization.data(withJSONObject: convertSectionsToDict(assessment.sections))
        if let sectionsString = String(data: sectionsData, encoding: .utf8) {
            assessmentDict["sections"] = sectionsString
        }
        
        // Convert horses to JSON
//        let horsesData = try JSONSerialization.data(withJSONObject: convertHorsesToDict(assessment.horses))
//        if let horsesString = String(data: horsesData, encoding: .utf8) {
//            assessmentDict["horses"] = horsesString
//        }
        
        return assessmentDict
    }
    
    /// Converts sections to an array of dictionaries
    /// - Parameter sections: The sections to convert
    /// - Returns: An array of dictionaries representing the sections
    private func convertSectionsToDict(_ sections: [Section]) -> [[String: Any]] {
        return sections.map { section in
            var sectionDict: [String: Any] = [
                "id": section.id,
                "title": section.title,
                "is_applicable": section.isApplicable
            ]
            
            // Convert subsections
            sectionDict["subsections"] = section.subsections.map { subsection in
                var subsectionDict: [String: Any] = [
                    "id": subsection.id,
                    "name": subsection.name
                ]
                
                // Convert requirements
                subsectionDict["requirements"] = subsection.requirements.map { requirement in
                    var requirementDict: [String: Any] = [
                        "id": requirement.id,
                        "text": requirement.text,
                        "compliance_status": requirement.complianceStatus?.rawValue ?? "not_evaluated"
                    ]
                    
                    if let reason = requirement.nonComplianceReason {
                        requirementDict["non_compliance_reason"] = reason
                    }
                    
                    return requirementDict
                }
                
                return subsectionDict
            }
            
            return sectionDict
        }
    }
    
    /// Converts horses to an array of dictionaries
    /// - Parameter horses: The horses to convert
    /// - Returns: An array of dictionaries representing the horses
//    private func convertHorsesToDict(_ horses: [Horse]) -> [[String: Any]] {
//        return horses.map { horse in
//            var horseDict: [String: Any] = [
//                "id": horse.id.uuidString,
//                "name": horse.name
//            ]
//            
//            // Add more horse properties as needed
//            
//            return horseDict
//        }
//    }
}
