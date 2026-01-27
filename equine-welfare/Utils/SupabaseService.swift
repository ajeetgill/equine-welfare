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
    private var client: SupabaseClient
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern
    private init() {
        guard let supabaseUrlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let supabaseKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as? String,
              let supabaseUrl = URL(string: supabaseUrlString) else {
            fatalError("Supabase configuration not found or invalid. Ensure Secrets.xcconfig is properly configured.")
        }
        
        self.client = SupabaseClient(
            supabaseURL: supabaseUrl,
            supabaseKey: supabaseKey
        )
    }
    
    // MARK: - Public Methods
    
    /// Checks if Supabase credentials are available
    /// - Returns: Boolean indicating if Supabase can be used
    static func areCredentialsAvailable() -> Bool {
        guard let supabaseUrlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let supabaseKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as? String,
              URL(string: supabaseUrlString) != nil else {
            return false
        }

        return true
    }
    
    // MARK: - Public Methods
    
    /// Uploads an RTF file to Supabase Storage
    /// - Parameters:
    ///   - fileURL: The local URL of the RTF file to upload
    ///   - assessment: The assessment associated with the file
    /// - Returns: A result with a success message or an error
    func uploadRTFDocument(fileURL: URL, assessment: Assessment) async -> Result<String, Error> {
        do {
            // Verify the file exists and can be read
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return .failure(NSError(
                    domain: "SupabaseService",
                    code: 1003,
                    userInfo: [NSLocalizedDescriptionKey: "RTF file not found"]
                ))
            }
            
            // Create a sanitized folder name based on assessment name
            let sanitizedFolderName = assessment.displayName.replacingOccurrences(of: "/", with: "-")
            
            // Create a file name using the assessment name and date
            let fileName = "\(sanitizedFolderName).rtf"
            
            // Full path in storage will be: assessments/{sanitizedFolderName}/{fileName}
            let storagePath = "assessments/\(sanitizedFolderName)/\(fileName)"
            
            // Read the file data
            do {
                let fileData = try Data(contentsOf: fileURL)

                // Upload to Supabase Storage
                let response = try await client.storage
                    .from("assessments")
                    .upload(
                        path: "\(sanitizedFolderName)/\(fileName)",
                        file: fileData,
                        options: FileOptions(contentType: "application/rtf")
                    )

                return .success("Assessment document uploaded successfully 🎉 yeehaw 🐴")
            } catch let error {
                // Check if this is a "resource already exists" error
                if error.localizedDescription.contains("already exists") {
                    return .failure(NSError(
                        domain: "SupabaseService",
                        code: 1006,
                        userInfo: [NSLocalizedDescriptionKey: "This assessment has already been uploaded. Duplicate uploads are not allowed."]
                    ))
                } else {
                    return .failure(error)
                }
            }
        } catch {
            return .failure(error)
        }
    }
    
    /// Uploads JSON assessment data to Supabase Storage
    /// - Parameter assessment: The assessment to upload
    /// - Returns: A result with a success message or an error
    func uploadJSONData(for assessment: Assessment) async -> Result<String, Error> {
        do {
            // Generate JSON data using our exporter
            guard let jsonString = AssessmentJSONExporter.generateJSON(from: assessment) else {
                return .failure(NSError(
                    domain: "SupabaseService",
                    code: 1007,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to generate JSON data"]
                ))
            }
            
            // Convert string to data
            guard let jsonData = jsonString.data(using: .utf8) else {
                return .failure(NSError(
                    domain: "SupabaseService",
                    code: 1008,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON to data"]
                ))
            }
            
            // Create a sanitized folder name based on assessment name
            let sanitizedFolderName = assessment.displayName.replacingOccurrences(of: "/", with: "-")
            
            // Create a file name using the assessment name
            let fileName = "\(sanitizedFolderName).json"
            
            // Full path in storage will be: assessments/{sanitizedFolderName}/{fileName}
            let storagePath = "assessments/\(sanitizedFolderName)/\(fileName)"
            
            // Upload to Supabase Storage
            let response = try await client.storage
                .from("assessments")
                .upload(
                    path: "\(sanitizedFolderName)/\(fileName)",
                    file: jsonData,
                    options: FileOptions(contentType: "application/json")
                )

            return .success("Assessment JSON data uploaded successfully")
        } catch let error {
            // Check if this is a "resource already exists" error
            if error.localizedDescription.contains("already exists") {
                return .failure(NSError(
                    domain: "SupabaseService",
                    code: 1009,
                    userInfo: [NSLocalizedDescriptionKey: "This assessment JSON has already been uploaded."]
                ))
            } else {
                return .failure(error)
            }
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
        
        // Collect all media attachments from the assessment along with their subsection names
        var allMediaAttachmentsWithContext: [(attachment: MediaAttachment, subsectionName: String)] = []
        
        // Traverse the assessment structure to find all media attachments
        for section in assessment.sections where section.isApplicable {
            for subsection in section.subsections {
                for requirement in subsection.requirements {
                    // For each attachment, pair it with its subsection name
                    let attachmentsWithContext = requirement.mediaAttachments.map {
                        ($0, subsection.name)
                    }
                    allMediaAttachmentsWithContext.append(contentsOf: attachmentsWithContext)
                }
            }
        }
        
        // If no media attachments found, return early
        if allMediaAttachmentsWithContext.isEmpty {
            return .success(0)
        }
        
        // Track upload progress
        var successCount = 0
        var errorCount = 0
        let totalCount = allMediaAttachmentsWithContext.count
        
        // Create a task group for concurrent uploads
        do {
            // Use a simple approach with a loop instead of task groups for better control
            for (index, attachmentWithContext) in allMediaAttachmentsWithContext.enumerated() {
                do {
                    let attachment = attachmentWithContext.attachment
                    let subsectionName = attachmentWithContext.subsectionName
                    
                    // Create a unique filename based on subsection name, attachment ID, and timestamp
                    let timestamp = Int(Date().timeIntervalSince1970)
                    
                    // Sanitize subsection name for use in filename
                    let sanitizedSubsectionName = subsectionName.replacingOccurrences(of: "/", with: "-")
                                                               .replacingOccurrences(of: " ", with: "_")
                    
                    let fileName = "\(sanitizedSubsectionName)_media_\(attachment.id)_\(timestamp).\(attachment.mediaType.fileExtension)"
                    let path = "\(sanitizedFolderName)/media/\(fileName)"

                    // Upload the file to Supabase with correct content type
                    _ = try await client.storage
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
                        
                        _ = try await client.storage
                            .from("assessments")
                            .upload(
                                path: path,
                                file: photoData.data,
                                options: FileOptions(contentType: "image/jpeg")
                            )
                        successCount += 1
                        horsePhotosUploaded += 1
                    } catch {
                        errorCount += 1
                    }
                }

                // Upload body view photos if they exist
                let bodyPhotos: [(Data?, String)] = [
                    (horse.frontPhotoData?.data, "front"),
                    (horse.rightPhotoData?.data, "right"),
                    (horse.backPhotoData?.data, "back"),
                    (horse.leftPhotoData?.data, "left")
                ]
                
                for (photoData, view) in bodyPhotos {
                    if let data = photoData {
                        do {
                            let fileName = "\(view)_view.jpg"
                            let path = "\(sanitizedFolderName)/horses/\(sanitizedHorseName)/\(fileName)"
                            
                            _ = try await client.storage
                                .from("assessments")
                                .upload(
                                    path: path,
                                    file: data,
                                    options: FileOptions(contentType: "image/jpeg")
                                )
                            successCount += 1
                            horsePhotosUploaded += 1
                        } catch {
                            errorCount += 1
                        }
                    }
                }

                // Upload abnormal photos if they exist
                for (abnormalIndex, abnormalData) in horse.abnormalPhotosData.enumerated() {
                    do {
                        // Use the correct file extension and MIME type based on mediaType
                        let fileExtension = abnormalData.mediaType.fileExtension
                        let mimeType = abnormalData.mediaType.mimeType
                        let fileName = "abnormal_\(abnormalIndex + 1).\(fileExtension)"
                        let path = "\(sanitizedFolderName)/horses/\(sanitizedHorseName)/abnormal/\(fileName)"
                        
                        _ = try await client.storage
                            .from("assessments")
                            .upload(
                                path: path,
                                file: abnormalData.data,
                                options: FileOptions(contentType: mimeType)
                            )
                        successCount += 1
                        horsePhotosUploaded += 1
                    } catch {
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
            return .failure(error)
        }
    }

    /// Prints the assessment data for debugging purposes
    /// - Parameter assessment: The assessment to print
    func printAssessmentData(_ assessment: Assessment) {
        // Debug print statements removed for production
    }
    
    /// Checks if an assessment already exists in storage
    /// - Parameter assessment: The assessment to check
    /// - Returns: A result indicating whether the assessment exists or not, with an error if the check fails
    private func checkAssessmentExists(for assessment: Assessment) async -> Result<Bool, Error> {
        do {
            // Create a sanitized folder name based on assessment name
            let sanitizedFolderName = assessment.displayName.replacingOccurrences(of: "/", with: "-")
            
            // Check if any files exist in the assessments folder with this name
            let response = try await client.storage
                .from("assessments")
                .list(path: sanitizedFolderName)
            
            // If we get any results, the assessment already exists
            return .success(!response.isEmpty)
        } catch {
            return .failure(error)
        }
    }
    
    /// Uploads all assessment data including horses, documents, and media to Supabase
    /// - Parameters:
    ///   - assessment: The assessment to upload
    ///   - modelContext: The SwiftData model context
    ///   - progressHandler: Optional closure to handle upload progress updates
    /// - Returns: A result with success or failure
    func uploadAssessmentComplete(assessment: Assessment, modelContext: ModelContext, progressHandler: ((String, Double) -> Void)? = nil) async -> Result<Bool, Error> {
        do {
            // First check if this assessment already exists
            progressHandler?("Checking for existing uploads...", 0.05)
            let existsResult = await checkAssessmentExists(for: assessment)
            
            switch existsResult {
            case .success(let exists):
                if exists {
                    return .failure(NSError(
                        domain: "SupabaseService",
                        code: 1005,
                        userInfo: [NSLocalizedDescriptionKey: "This assessment has already been uploaded. Duplicate uploads are not allowed."]
                    ))
                }
            case .failure:
                // Continue anyway since this is just a precaution
                break
            }
            
            // Step 1: Upload horse data as JSON
            progressHandler?("Uploading horse data...", 0.1)

            let horses = assessment.horses
            let horseDicts = horses.map { horse -> [String: Any] in
                var dict: [String: Any] = [
                    "uuid": horse.uuid.uuidString,
                    "name": horse.name,
                    "age": horse.age,
                    "color": horse.color,
                    "sex": horse.sex,
                    "breed": horse.breed,
                    "timeOnFarm": horse.timeOnFarm,
                    "bcsScore": horse.bcsScore,
                    "ageUnit": horse.ageUnit.rawValue,
                    "timeUnit": horse.timeUnit.rawValue,
                    "isHorse": horse.isHorse
                ]
                if let otherBreed = horse.otherBreed { dict["otherBreed"] = otherBreed }
                if let notes = horse.notes { dict["notes"] = notes }
                return dict
            }

            if let jsonData = try? JSONSerialization.data(withJSONObject: horseDicts, options: .prettyPrinted) {
                let sanitizedFolderName = assessment.displayName.replacingOccurrences(of: "/", with: "-")
                let storagePath = "\(sanitizedFolderName)/horses/horse_data.json"

                _ = try? await client.storage
                    .from("assessments")
                    .upload(path: storagePath, file: jsonData, options: FileOptions(contentType: "application/json"))
            }
            
            // Step 2: Upload RTF document - it is intentionally not deleted
            // progressHandler?("Uploading assessment document...", 0.3)
            // if let rtfURL = await getRTFDocumentURL(for: assessment) {
            //     let documentResult = await uploadRTFDocument(fileURL: rtfURL, assessment: assessment)
                
            //     switch documentResult {
            //     case .failure(let error):
            //         // If the error indicates the document already exists, stop the entire process
            //         if error.localizedDescription.contains("already been uploaded") {
            //             print("Stopping upload process - assessment already exists")
            //             return .failure(error)
            //         }
            //         print("Warning: RTF document upload failed: \(error.localizedDescription)")
            //         // For other errors, we'll continue with media uploads
            //     case .success(_):
            //         // Document upload succeeded, continue
            //         break
            //     }
            // }
            
            // Step 2: Upload JSON data
            progressHandler?("Uploading assessment Document...", 0.4)
            let jsonResult = await uploadJSONData(for: assessment)
            switch jsonResult {
            case .failure(let error):
                if error.localizedDescription.contains("already been uploaded") {
                    progressHandler?("Upload failed - Assessment already exists", 1.0)
                    return .failure(NSError(
                        domain: "SupabaseService",
                        code: 1010,
                        userInfo: [NSLocalizedDescriptionKey: "This assessment has already been uploaded. Duplicate uploads are not allowed."]
                    ))
                }
                // Continue with other uploads even if this one failed
            case .success(_):
                // JSON upload succeeded, continue
                break
            }
            
            // Step 3: Upload assessment media
            progressHandler?("Uploading assessment media...", 0.5)
            let mediaResult = await uploadAssessmentMedia(assessment: assessment) { progress in
                progressHandler?("Uploading assessment media...", 0.5 + progress * 0.15)
            }
            
            // Step 4: Upload horse media
            progressHandler?("Uploading horse photos...", 0.65)
            let horseMediaResult = await uploadHorseMedia(assessment: assessment) { progress in
                progressHandler?("Uploading horse photos...", 0.65 + progress * 0.35)
            }
            
            // Final progress update
            progressHandler?("Upload complete!", 1.0)
            
            return .success(true)
        } catch {
            return .failure(error)
        }
    }
    
    // Helper method to get RTF document URL
    private func getRTFDocumentURL(for assessment: Assessment) async -> URL? {
        // Find the RTF file in the temporary directory using the same naming convention as in PreviousAssessmentRow
        let tempDir = FileManager.default.temporaryDirectory
        let sanitizedName = assessment.displayName.replacingOccurrences(of: "/", with: "-")
        let fileName = "\(sanitizedName).rtf"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Check if the file exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        } else {
            return nil
        }
    }
}
