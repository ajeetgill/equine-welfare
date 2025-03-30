import SwiftUI
import SwiftData
import PhotosUI

struct HorseInfoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let horseId: UUID
    
    // Callback for edit actions
    var onEdit: ((UUID, UUID) -> Void)?
    
    @State private var horse: Horse?
    @State private var findings: String = ""
    
    // Photo pickers for each side, separate state variables for each picker
    @State private var showingFrontPicker = false
    @State private var showingRightPicker = false
    @State private var showingBackPicker = false
    @State private var showingLeftPicker = false
    @State private var showingAbnormalFindings = false
    
    // Add assessmentId access
    private var assessmentId: UUID? {
        // Get the assessment ID from the horse's relationship
        return horse?.assessment?.id
    }
    
    init(
        horseId: UUID, 
        onEdit: ((UUID, UUID) -> Void)? = nil
    ) {
        self.horseId = horseId
        self.onEdit = onEdit
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Horse header with photo and basic info
                horseHeaderView
                
                // Findings or Extra Details section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Findings or Extra Details")
                        .font(.headline)
                    
                    TextField("Enter any findings or notes here", text: $findings, axis: .vertical)
                        .lineLimit(5...10)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onChange(of: findings) { _, newValue in
                            saveFindings(newValue)
                        }
                }
                
                // Body Photos section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Body Photos")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        VStack{
                            if let data = horse?.frontPhotoData?.data, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 70, height: 70)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Image("horse-icon")
                                            .resizable()
                                            .scaledToFit()
                                            .grayscale(1)
                                            .padding(12)
                                            .foregroundColor(.gray)
                                    )
                            }
                            Text("Front")
                            MediaPicker(isPresented: $showingFrontPicker, cameraText: "", galleryText: "") {
                                mediaData, mediaType in
                                let attachment =
                                mediaType == .image
                                ? MediaAttachment(imageData: mediaData)
                                : MediaAttachment(videoData: mediaData)
                                horse?.frontPhotoData = attachment
                                try? modelContext.save()
                            }
                            .cornerRadius(30)
                            .background(Color(.systemGray6).opacity(0.2))
                        }
                        
                        VStack {
                            if let data = horse?.rightPhotoData?.data, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 70, height: 70)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Image("horse-icon")
                                            .resizable()
                                            .scaledToFit()
                                            .grayscale(1)
                                            .padding(12)
                                            .foregroundColor(.gray)
                                    )
                            }
                            Text("Right")
                            MediaPicker(isPresented: $showingRightPicker, cameraText: "", galleryText: "") {
                                mediaData, mediaType in
                                let attachment =
                                mediaType == .image
                                ? MediaAttachment(imageData: mediaData)
                                : MediaAttachment(videoData: mediaData)
                                horse?.rightPhotoData = attachment
                                try? modelContext.save()
                            }
                            .cornerRadius(30)
                            .background(Color(.systemGray6).opacity(0.2))
                        }
                        
                        VStack {
                            if let data = horse?.backPhotoData?.data, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 70, height: 70)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Image("horse-icon")
                                            .resizable()
                                            .scaledToFit()
                                            .grayscale(1)
                                            .padding(12)
                                            .foregroundColor(.gray)
                                    )
                            }
                            Text("Back")
                            MediaPicker(isPresented: $showingBackPicker, cameraText: "", galleryText: "") {
                                mediaData, mediaType in
                                let attachment =
                                mediaType == .image
                                ? MediaAttachment(imageData: mediaData)
                                : MediaAttachment(videoData: mediaData)
                                horse?.backPhotoData = attachment
                                try? modelContext.save()
                            }
                            .cornerRadius(30)
                            .background(Color(.systemGray6).opacity(0.2))
                        }
                        
                        VStack {
                            if let data = horse?.leftPhotoData?.data, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 70, height: 70)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Image("horse-icon")
                                            .resizable()
                                            .scaledToFit()
                                            .grayscale(1)
                                            .padding(12)
                                            .foregroundColor(.gray)
                                    )
                            }
                            Text("Left")
                            MediaPicker(isPresented: $showingLeftPicker, cameraText: "", galleryText: "") {
                                mediaData, mediaType in
                                let attachment =
                                mediaType == .image
                                ? MediaAttachment(imageData: mediaData)
                                : MediaAttachment(videoData: mediaData)
                                horse?.leftPhotoData = attachment
                                try? modelContext.save()
                            }
                            .cornerRadius(30)
                            .background(Color(.systemGray6).opacity(0.2))
                        }
                    }
                    .fontWeight(.semibold)
                    .font(.caption)
                }
                
                // Abnormal Findings section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Abnormal Findings")
                    
                    Text("E.g.Not limited to but here you can include photos of injuries, hooves, teeth, skin, etc")
                        .font(.caption)
                        .foregroundColor(.gray)
                    // Add photo button
                    addAbnormalPhotoButton()
                    // Grid of abnormal photos with add button
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)], spacing: 16) {
                        // Display existing abnormal photos
                        ForEach(horse?.abnormalPhotosData ?? [], id: \.id) { abnormalPhoto in
                            if let uiImage = UIImage(data: abnormalPhoto.data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            removeAbnormalPhoto(abnormalPhoto)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
//                                    .overlay(
//                                        Button(action: {
//                                            removeAbnormalPhoto(abnormalPhoto)
//                                        }) {
//                                            Image(systemName: "xmark.circle.fill")
//                                                .foregroundColor(.white)
//                                                .background(Color.black.opacity(0.7))
//                                                .clipShape(Circle())
//                                        }
//                                        .padding(4),
//                                        alignment: .topTrailing
//                                    )
                                    
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(horse?.name ?? "Horse Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    if let horse = horse, let assessId = assessmentId {
                        
                        // Use the callback if provided
                        if let onEdit = onEdit {
                            onEdit(horse.uuid, assessId)
                        }
                    } else if let horse = horse {
                        print("ERROR: Missing assessment ID when trying to edit horse: \(horse.name)")
                        
                        // Try to find the assessment
                        Task {
                            if let foundAssessmentId = await findAssessmentForHorse(horse.uuid) {
                                // Use the callback if provided
                                if let onEdit = onEdit {
                                    onEdit(horse.uuid, foundAssessmentId)
                                }
                            } else {
                                dismiss()
                            }
                        }
                    }
                }
                .disabled(horse == nil)
            }
        }
        .onAppear {
            loadHorse()
        }
        .onChange(of: horseId) { _, newId in
            loadHorse()  // Reload horse data when horseId changes
        }
    }
    
    private var horseHeaderView: some View {
        HStack(spacing: 16) {
            // Horse image
            if let horse = horse, let photoData = horse.photoData, let uiImage = UIImage(data: photoData.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image("horse-icon")
                    .resizable()
                    .scaledToFit()
                    .grayscale(1)
                    .frame(width: 60, height: 60)
                    .padding(10)
                    .foregroundColor(.gray)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Horse details
            if let horse = horse {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(horse.name) - \(horse.age) \(horse.ageUnit.rawValue) old")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Text("Breed : \(horse.breed)")
                            .font(.caption)
                        
                        Text("Time on Farm : \(horse.timeOnFarm) \(horse.timeUnit.rawValue)")
                            .font(.caption)
                    }
                    
                    HStack(spacing: 12) {
                        Text("Color : \(horse.color)")
                            .font(.caption)
                        
                        Text("Sex : \(horse.sex)")
                            .font(.caption)
                        
                        Text("BCS : \(String(format: "%.1f", horse.bcsScore))")
                            .font(.caption)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func addAbnormalPhotoButton() -> some View {
        VStack{
            MediaPicker(isPresented: $showingAbnormalFindings, cameraText: "", galleryText: "") {
                mediaData, mediaType in
                guard let horse = horse else { return }
                
                // Create a new MediaAttachment and insert it into the model context
                let attachment = mediaType == .image
                    ? MediaAttachment(imageData: mediaData)
                    : MediaAttachment(videoData: mediaData)
                
                // Insert the attachment directly into the context first
                modelContext.insert(attachment)
                
                // Add the attachment to the horse's abnormalPhotosData array
                horse.abnormalPhotosData.append(attachment)
                
                // Try to save immediately
                do {
                    try modelContext.save()
                    print("DEBUG: Successfully saved changes to model context")
                } catch {
                    print("ERROR: Failed to save attachment: \(error.localizedDescription)")
                }
            }
            .cornerRadius(30)
            .background(Color(.systemGray6).opacity(0.2))
        }
    }
    
    private func removeAbnormalPhoto(_ photo: MediaAttachment) {
        guard let horse = horse else { return }
        
        // Remove it from the horse's array
        if let index = horse.abnormalPhotosData.firstIndex(where: { $0.id == photo.id }) {
            horse.abnormalPhotosData.remove(at: index)
            
            // Delete it from the model context, & save changes
            modelContext.delete(photo)
            try? modelContext.save()
        }
    }
    
    private func processPhotoItem(_ item: PhotosPickerItem?, completion: @escaping (Data?) -> Void) {
        guard let item = item else {
            completion(nil)
            return
        }
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    completion(data)
                case .failure(let error):
                    print("Photo loading error: \(error)")
                    completion(nil)
                }
            }
        }
    }
    
    private func saveFindings(_ newFindings: String) {
        guard let horse = horse else { return }
        
        horse.notes = newFindings
        try? modelContext.save()
    }
    
    private func loadHorse() {
        do {
            // Create a descriptor that also includes relationship information
            var descriptor = FetchDescriptor<Horse>(
                predicate: #Predicate<Horse> { horse in
                    horse.uuid == horseId
                }
            )
            
            // Add relationship descriptors to ensure Assessment is loaded
            descriptor.includePendingChanges = true
            
            if let loadedHorse = try modelContext.fetch(descriptor).first {
                self.horse = loadedHorse
                self.findings = loadedHorse.notes ?? ""
                
                // TODO: check if i need the below code block about repairing relationship
                // Debug output to check the assessment relationship
                if let assessment = loadedHorse.assessment {
                    print("DEBUG: Horse belongs to assessment: \(assessment.id)")
                }
            } else {
                print("ERROR: Horse with ID \(horseId) not found")
            }
        } catch {
            print("ERROR: Loading horse failed: \(error.localizedDescription)")
        }
    }
    
    // Helper to find the assessment for a horse
    private func findAssessmentForHorse(_ horseId: UUID) async -> UUID? {
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                do {
                    // Get all assessments
                    let assessments = try modelContext.fetch(FetchDescriptor<Assessment>())
                    
                    // Find the assessment containing this horse
                    for assessment in assessments {
                        if assessment.horses.contains(where: { $0.uuid == horseId }) {
                            continuation.resume(returning: assessment.id)
                            return
                        }
                    }
                    
                    // Not found
                    continuation.resume(returning: nil)
                } catch {
                    print("ERROR: Finding assessment failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

#Preview {
    let modelContext = ModelContext(try! ModelContainer(for: Horse.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    
    // Create a sample horse for preview
    let horse = Horse(
        name: "Red",
        age: 4,
        color: "Appaloosa",
        sex: "Gelding",
        breed: "Albanian",
        timeOnFarm: 4,
        bcsScore: 4.0
    )
//    modelContext.insert(horse)
    
    NavigationStack {
        HorseInfoView(
            horseId: horse.uuid
        )
    }
    .modelContainer(for: Horse.self, inMemory: true)
}
