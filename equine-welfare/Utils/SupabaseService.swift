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
            
            return .success("Assessment document uploaded successfully 🎉 yeehaw 🐴")
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
                    // Create a unique filename based on attachment ID, timestamp, and media type
                    let timestamp = Int(Date().timeIntervalSince1970)
                    let fileName = "media_\(attachment.id)_\(timestamp).\(attachment.mediaType.fileExtension)"
                    let path = "\(sanitizedFolderName)/media/\(fileName)"
                    
                    print("Uploading media file: \(fileName) with type: \(attachment.mediaType.mimeType)")
                    
                    // Upload the file to Supabase with correct content type
                    _ = try await supabase.storage
                        .from("assessments")
                        .upload(
                            path: path,
                            file: attachment.data,
                            options: FileOptions(contentType: attachment.mediaType.mimeType)
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
                return .failure(NSError(
                    domain: "SupabaseService",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to upload all media attachments. Total attempts: \(totalCount)"]
                ))
            }
            
            return .success(successCount)
        } catch {
            print("Error in upload process: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    /// Uploads horse media to Supabase Storage
    /// - Parameters:
    ///   - assessment: The assessment containing horses with media attachments
    ///   - progressHandler: Optional closure to handle upload progress updates (0.0 to 1.0)
    /// - Returns: A result containing the number of successfully uploaded files or an error
    func uploadHorseMedia(assessment: Assessment, progressHandler: ((Double) -> Void)? = nil) async -> Result<Int, Error> {
        var successCount = 0
        var errorCount = 0
        let totalHorses = assessment.horses.count
        
        do {
            // Create a sanitized folder name based on assessment name (same naming convention as RTF upload)
            let sanitizedFolderName = assessment.displayName.replacingOccurrences(of: "/", with: "-")
            
            for (index, horse) in assessment.horses.enumerated() {
                // Create a sanitized folder name for the horse
                let sanitizedHorseName = horse.name.replacingOccurrences(of: "/", with: "-")
                var horsePhotosUploaded = 0
                
                // Upload main photo if exists
                if let photoData = horse.photoData {
                    do {
                        let fileName = "main_photo.jpg"
                        let path = "\(sanitizedFolderName)/horses/\(sanitizedHorseName)/\(fileName)"
                        
                        _ = try await supabase.storage
                            .from("assessments")
                            .upload(
                                path: path,
                                file: photoData,
                                options: FileOptions(contentType: "image/jpeg")
                            )
                        successCount += 1
                        horsePhotosUploaded += 1
                    } catch {
                        print("Error uploading main horse photo: \(error.localizedDescription)")
                        errorCount += 1
                    }
                }
                
                // Upload body view photos if they exist
                let bodyPhotos: [(Data?, String)] = [
                    (horse.frontPhotoData, "front"),
                    (horse.rightPhotoData, "right"),
                    (horse.backPhotoData, "back"),
                    (horse.leftPhotoData, "left")
                ]
                
                for (photoData, view) in bodyPhotos {
                    if let data = photoData {
                        do {
                            let fileName = "\(view)_view.jpg"
                            let path = "\(sanitizedFolderName)/horses/\(sanitizedHorseName)/\(fileName)"
                            
                            _ = try await supabase.storage
                                .from("assessments")
                                .upload(
                                    path: path,
                                    file: data,
                                    options: FileOptions(contentType: "image/jpeg")
                                )
                            successCount += 1
                            horsePhotosUploaded += 1
                        } catch {
                            print("Error uploading \(view) view photo: \(error.localizedDescription)")
                            errorCount += 1
                        }
                    }
                }
                
                // Upload abnormal photos if they exist
                for (abnormalIndex, abnormalData) in horse.abnormalPhotosData.enumerated() {
                    do {
                        let fileName = "abnormal_\(abnormalIndex + 1).jpg"
                        let path = "\(sanitizedFolderName)/horses/\(sanitizedHorseName)/abnormal/\(fileName)"
                        
                        _ = try await supabase.storage
                            .from("assessments")
                            .upload(
                                path: path,
                                file: abnormalData,
                                options: FileOptions(contentType: "image/jpeg")
                            )
                        successCount += 1
                        horsePhotosUploaded += 1
                    } catch {
                        print("Error uploading abnormal photo: \(error.localizedDescription)")
                        errorCount += 1
                    }
                }
                
                // Calculate progress based on current horse
                let progress = Double(index + 1) / Double(totalHorses)
                progressHandler?(progress)
            }
            
            // If all uploads failed and there were attempts
            if errorCount > 0 && successCount == 0 {
                return .failure(NSError(
                    domain: "SupabaseService",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to upload all horse media attachments."]
                ))
            }
            
            return .success(successCount)
        } catch {
            print("Error in horse media upload process: \(error.localizedDescription)")
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
   
    
}
