import SwiftData
import Foundation
import Supabase

class HorseService {
    
    private static let supabaseURL = URL(string: "https://aknlkmbwbbnfxaoqljzd.supabase.co")!
    private static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFrbmxrbWJ3YmJuZnhhb3FsanpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEzOTEyMTQsImV4cCI6MjA1Njk2NzIxNH0.kjZRF_JwWN9ovTahZFmGcj9h6XgIhApWTVCrAA6o8ZQ"
    
    // Create a Supabase client instance
    private static let supabase = SupabaseClient(
        supabaseURL: supabaseURL,
        supabaseKey: supabaseKey
    )
    
    static func fetchHorses(modelContext: ModelContext, forAssessment assessmentId: UUID? = nil) -> [Horse] {
        var fetchDescriptor = FetchDescriptor<Horse>()
        
        if let assessmentId = assessmentId {
            fetchDescriptor.predicate = #Predicate<Horse> { 
                $0.assessment?.id == assessmentId
            }
        }
        
        do {
            let horses = try modelContext.fetch(fetchDescriptor)
            return horses
        } catch {
            print("Error fetching horses: \(error)")
            return []
        }
    }
    
    static func encodeHorsesToJSON(horses: [Horse]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        // Create a dictionary with only the fields we want to encode
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
            
            // Add optional fields if they exist
            if let otherBreed = horse.otherBreed {
                dict["otherBreed"] = otherBreed
            }
            
            if let notes = horse.notes {
                dict["notes"] = notes
            }
            
            return dict
        }
        
        do {
            return try JSONSerialization.data(withJSONObject: horseDicts, options: .prettyPrinted)
        } catch {
            print("Error encoding horses to JSON: \(error)")
            return nil
        }
    }
    
    // Original method - sends horses to an HTTP endpoint
    static func sendHorses(modelContext: ModelContext) {
        let horses = fetchHorses(modelContext: modelContext)
        
        guard let jsonData = encodeHorsesToJSON(horses: horses) else {
            print("Failed to encode JSON data")
            return
        }

        let url = URL(string: "https://example.com/api/horses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending data: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Response status code: \(httpResponse.statusCode)")
            }
        }
        task.resume()
        
        // Also upload to Supabase storage
        Task {
            do {
                await uploadHorsesToSupabase(modelContext: modelContext)
            } catch {
                print("Error uploading horses to Supabase: \(error.localizedDescription)")
            }
        }
    }
    
    // New method - uploads horses to Supabase storage as a JSON file
    static func uploadHorsesToSupabase(modelContext: ModelContext) async -> Result<String, Error> {
        do {
            // Fetch horses and encode to JSON
            let horses = fetchHorses(modelContext: modelContext)
            
            guard let jsonData = encodeHorsesToJSON(horses: horses) else {
                return .failure(NSError(
                    domain: "HorseService",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to encode horses to JSON"]
                ))
            }
            
            // Create a timestamp for the filename
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "horses_\(timestamp).json"
            
            // Full path in storage will be: horses/{fileName}
            let storagePath = "horses/\(fileName)"
            
            // Upload to Supabase Storage
            let response = try await supabase.storage
                .from("assessments") // Using the same bucket as other uploads
                .upload(
                    path: storagePath,
                    file: jsonData,
                    options: FileOptions(contentType: "application/json")
                )
            
            print("Horse data uploaded to Supabase storage: \(storagePath)")
            return .success("Horses uploaded successfully to Supabase storage")
        } catch {
            print("Error uploading horses to Supabase: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    // Upload horses to Supabase with a specific folder name for better organization
    static func uploadHorsesForAssessment(modelContext: ModelContext, assessmentName: String, assessmentId: UUID) async -> Result<String, Error> {
        do {
            // Fetch horses for the specific assessment only
            let horses = fetchHorses(modelContext: modelContext, forAssessment: assessmentId)
            
            guard let jsonData = encodeHorsesToJSON(horses: horses) else {
                return .failure(NSError(
                    domain: "HorseService",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to encode horses to JSON"]
                ))
            }
            
            // Create a sanitized folder name from the assessment name
            let sanitizedFolderName = assessmentName.replacingOccurrences(of: "/", with: "-")
            let fileName = "horse_data.json"
            
            // Full path in storage will be: assessments/{sanitizedFolderName}/horses/{fileName}
            let storagePath = "\(sanitizedFolderName)/horses/\(fileName)"
            
            // Upload to Supabase Storage
            let response = try await supabase.storage
                .from("assessments")
                .upload(
                    path: storagePath,
                    file: jsonData,
                    options: FileOptions(contentType: "application/json")
                )
            
            print("Horse data uploaded to Supabase storage: \(storagePath)")
            return .success("Horses uploaded successfully to Supabase storage")
        } catch {
            print("Error uploading horses to Supabase: \(error.localizedDescription)")
            return .failure(error)
        }
    }
}
