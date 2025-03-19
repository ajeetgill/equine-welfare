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
    
    // Photo pickers for each side
    @State private var frontPhotoItem: PhotosPickerItem?
    @State private var rightPhotoItem: PhotosPickerItem?
    @State private var backPhotoItem: PhotosPickerItem?
    @State private var leftPhotoItem: PhotosPickerItem?
    
    // Photo data for each side
    @State private var frontPhotoData: Data?
    @State private var rightPhotoData: Data?
    @State private var backPhotoData: Data?
    @State private var leftPhotoData: Data?
    
    // Array of abnormal findings photos
    @State private var abnormalPhotos: [Data] = []
    
    // Add this with your other state variables at the top of the file
    @State private var abnormalPhotoItem: PhotosPickerItem?
    
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
                        .padding(.horizontal)
                    
                    TextField("Enter any findings or notes here", text: $findings, axis: .vertical)
                        .lineLimit(5...10)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .onChange(of: findings) { _, newValue in
                            saveFindings(newValue)
                        }
                }
                
                // Body Photos section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Body Photos")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    HStack(spacing: 20) {
                        photoPickerButton(title: "Front", photoData: frontPhotoData, photoItem: $frontPhotoItem)
                        photoPickerButton(title: "Right Side", photoData: rightPhotoData, photoItem: $rightPhotoItem)
                        photoPickerButton(title: "Rear", photoData: backPhotoData, photoItem: $backPhotoItem)
                        photoPickerButton(title: "Left Side", photoData: leftPhotoData, photoItem: $leftPhotoItem)
                    }
                    .padding(.horizontal)
                }
                
                // Abnormal Findings section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Abnormal Findings")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    Text("E.g.Not limited to but here you can include photos of injuries, hooves, teeth, skin, etc")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    // Grid of abnormal photos with add button
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)], spacing: 16) {
                        // Display existing abnormal photos
                        ForEach(0..<abnormalPhotos.count, id: \.self) { index in
                            if let uiImage = UIImage(data: abnormalPhotos[index]) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        Button(action: {
                                            removeAbnormalPhoto(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.7))
                                                .clipShape(Circle())
                                        }
                                        .padding(4),
                                        alignment: .topTrailing
                                    )
                            }
                        }
                        
                        // Add photo button
                        addAbnormalPhotoButton()
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(horse?.name ?? "Horse Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    if let horse = horse, let assessId = assessmentId {
                        print("DEBUG: Edit button tapped for horse: \(horse.name)")
                        
                        // Use the callback if provided
                        if let onEdit = onEdit {
                            onEdit(horse.uuid, assessId)
                        } else {
                            print("DEBUG: No edit callback provided")
                        }
                    } else if let horse = horse {
                        print("ERROR: Missing assessment ID when trying to edit horse: \(horse.name)")
                        print("DEBUG: Attempting to find the assessment relationship")
                        
                        // Try to find the assessment
                        Task { @MainActor in
                            if let foundAssessmentId = await findAssessmentForHorse(horse.uuid) {
                                print("DEBUG: Found assessment ID: \(foundAssessmentId)")
                                
                                // Use the callback if provided
                                if let onEdit = onEdit {
                                    onEdit(horse.uuid, foundAssessmentId)
                                } else {
                                    print("DEBUG: No edit callback provided")
                                }
                            } else {
                                print("DEBUG: Could not find assessment for horse")
                                dismiss()
                            }
                        }
                    }
                }
                .disabled(horse == nil)
            }
        }
        .onAppear {
            print("DEBUG: HorseInfoView appeared for horse ID: \(horseId)")
            loadHorse()
        }
        .onChange(of: frontPhotoItem) { _, newValue in
            processPhotoItem(newValue) { data in
                frontPhotoData = data
                saveFrontPhoto(data)
            }
        }
        .onChange(of: rightPhotoItem) { _, newValue in
            processPhotoItem(newValue) { data in
                rightPhotoData = data
                saveRightPhoto(data)
            }
        }
        .onChange(of: backPhotoItem) { _, newValue in
            processPhotoItem(newValue) { data in
                backPhotoData = data
                saveBackPhoto(data)
            }
        }
        .onChange(of: leftPhotoItem) { _, newValue in
            processPhotoItem(newValue) { data in
                leftPhotoData = data
                saveLeftPhoto(data)
            }
        }
        .onChange(of: abnormalPhotoItem) { _, newValue in
            processPhotoItem(newValue) { data in
                if let imageData = data {
                    abnormalPhotos.append(imageData)
                    saveAbnormalPhotos()
                }
                // Reset the picker item after processing
                DispatchQueue.main.async {
                    abnormalPhotoItem = nil
                }
            }
        }
    }
    
    private var horseHeaderView: some View {
        HStack(spacing: 16) {
            // Horse image
            if let horse = horse, let photoData = horse.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
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
        .padding(.horizontal)
    }
    
    private func photoPickerButton(title: String, photoData: Data?, photoItem: Binding<PhotosPickerItem?>) -> some View {
        VStack {
            if let data = photoData, let uiImage = UIImage(data: data) {
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
                        Image(systemName: "pawprint.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    )
            }
            
            PhotosPicker(selection: photoItem, matching: .images) {
                HStack {
                    Image(systemName: "plus")
                    Text(title)
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
    }
    
    private func addAbnormalPhotoButton() -> some View {
        PhotosPicker(selection: $abnormalPhotoItem, matching: .images) {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
                
                Text("Add Photo")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private func removeAbnormalPhoto(at index: Int) {
        abnormalPhotos.remove(at: index)
        saveAbnormalPhotos()
    }
    
    private func saveFrontPhoto(_ data: Data?) {
        guard let horse = horse else { return }
        horse.frontPhotoData = data
        try? modelContext.save()
    }
    
    private func saveRightPhoto(_ data: Data?) {
        guard let horse = horse else { return }
        horse.rightPhotoData = data
        try? modelContext.save()
    }
    
    private func saveBackPhoto(_ data: Data?) {
        guard let horse = horse else { return }
        horse.backPhotoData = data
        try? modelContext.save()
    }
    
    private func saveLeftPhoto(_ data: Data?) {
        guard let horse = horse else { return }
        horse.leftPhotoData = data
        try? modelContext.save()
    }
    
    private func saveAbnormalPhotos() {
        guard let horse = horse else { return }
        horse.abnormalPhotosData = abnormalPhotos
        try? modelContext.save()
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
        print("DEBUG: Loading horse with ID: \(horseId)")
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
                print("DEBUG: Successfully loaded horse: \(loadedHorse.name)")
                self.horse = loadedHorse
                self.findings = loadedHorse.notes ?? ""
                
                // Debug output to check the assessment relationship
                if let assessment = loadedHorse.assessment {
                    print("DEBUG: Horse belongs to assessment: \(assessment.id)")
                } else {
                    print("CRITICAL: Horse has no assessment relationship - will fix")
                    
                    // Try to find and fix the relationship
                    Task { @MainActor in
                        if let assessmentId = await findAssessmentForHorse(horseId) {
                            print("DEBUG: Found containing assessment: \(assessmentId)")
                            
                            // Get the assessment object
                            let assessmentDescriptor = FetchDescriptor<Assessment>(
                                predicate: #Predicate { $0.id == assessmentId }
                            )
                            
                            if let assessment = try? modelContext.fetch(assessmentDescriptor).first {
                                print("DEBUG: Fixing missing relationship")
                                loadedHorse.assessment = assessment
                                
                                // Add the horse to the assessment if needed
                                if !assessment.horses.contains(where: { $0.uuid == horseId }) {
                                    assessment.horses.append(loadedHorse)
                                }
                                
                                try? modelContext.save()
                                
                                // Update our local copy
                                self.horse = loadedHorse
                            }
                        }
                    }
                }
                
                // Load body photos
                self.frontPhotoData = loadedHorse.frontPhotoData
                self.rightPhotoData = loadedHorse.rightPhotoData
                self.backPhotoData = loadedHorse.backPhotoData
                self.leftPhotoData = loadedHorse.leftPhotoData
                
                // Load abnormal photos
                self.abnormalPhotos = loadedHorse.abnormalPhotosData
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
                            print("DEBUG: Found containing assessment: \(assessment.id)")
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
    modelContext.insert(horse)
    
    return NavigationStack {
        HorseInfoView(
            horseId: horse.uuid
        )
    }
    .modelContainer(for: Horse.self, inMemory: true)
} 
