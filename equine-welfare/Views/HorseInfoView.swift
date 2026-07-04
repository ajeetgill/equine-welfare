import SwiftUI
import SwiftData
import PhotosUI
import AVKit

struct HorseInfoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let horseId: UUID
    
    // Callback for edit actions
    var onEdit: ((UUID, UUID) -> Void)?
    
    @State private var horse: Horse?
    @State private var findings: String = ""
    
    @State private var showingAbnormalFindings = false
    @State private var selectedMedia: MediaAttachment?
    
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
                        BodyPhotoWell(title: "Front", imageData: horse?.frontPhotoData?.data) {
                            horse?.frontPhotoData = $0
                            modelContext.saveOrLog("front photo")
                        }
                        BodyPhotoWell(title: "Right", imageData: horse?.rightPhotoData?.data) {
                            horse?.rightPhotoData = $0
                            modelContext.saveOrLog("right photo")
                        }
                        BodyPhotoWell(title: "Back", imageData: horse?.backPhotoData?.data) {
                            horse?.backPhotoData = $0
                            modelContext.saveOrLog("back photo")
                        }
                        BodyPhotoWell(title: "Left", imageData: horse?.leftPhotoData?.data) {
                            horse?.leftPhotoData = $0
                            modelContext.saveOrLog("left photo")
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
                        ForEach(horse?.abnormalPhotosData ?? [], id: \.id) { attachment in
                            MediaThumbnail(attachment: attachment, size: 100)
                                .onTapGesture {
                                    selectedMedia = attachment
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        removeAbnormalPhoto(attachment)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(item: $selectedMedia) { media in
            MediaViewer(attachment: media)
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
                    Text("\(horse.name) - \(horse.age) \(horse.ageUnit.rawValue) old (\(horse.isHorse ? "Horse" : "Donkey"))")
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
                        
                        Text("BCS : \(String(format: "%.1f", horse.bcsScore))/\(horse.isHorse ? "9" : "5")")
                            .font(.caption)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .shadow(color: Color.primary.opacity(0.1), radius: 2, x: 0, y: 1)
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
                modelContext.saveOrLog("abnormal photo")
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
            modelContext.saveOrLog("remove abnormal photo")
        }
    }
    
    private func saveFindings(_ newFindings: String) {
        guard let horse = horse else { return }
        
        horse.notes = newFindings
        modelContext.saveOrLog("findings")
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

/// One circular body-photo well (front/right/back/left): shows the captured
/// image or a placeholder, a caption, and a `MediaPicker` that hands back a new
/// attachment. Extracted from four identical inline copies.
private struct BodyPhotoWell: View {
    let title: String
    let imageData: Data?
    let onCapture: (MediaAttachment) -> Void

    @State private var showingPicker = false

    var body: some View {
        VStack {
            Group {
                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image("horse-icon")
                        .resizable()
                        .scaledToFit()
                        .grayscale(1)
                        .padding(12)
                        .foregroundColor(.gray)
                        .background(Color(.systemGray5))
                }
            }
            .frame(width: 70, height: 70)
            .clipShape(Circle())

            Text(title)

            MediaPicker(isPresented: $showingPicker, cameraText: "", galleryText: "") { mediaData, mediaType in
                let attachment = mediaType == .image
                    ? MediaAttachment(imageData: mediaData)
                    : MediaAttachment(videoData: mediaData)
                onCapture(attachment)
            }
            .cornerRadius(30)
            .background(Color(.systemGray6).opacity(0.2))
        }
    }
}

#Preview {
    let _ = ModelContext(try! ModelContainer(for: Horse.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))

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
    
    NavigationStack {
        HorseInfoView(
            horseId: horse.uuid
        )
    }
    .modelContainer(for: Horse.self, inMemory: true)
}
