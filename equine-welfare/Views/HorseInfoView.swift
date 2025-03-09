import SwiftUI
import SwiftData
import PhotosUI

struct HorseInfoView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationState: NavigationState
    
    let horseId: UUID
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
                    if let horse = horse {
                        navigationState.showHorseDetail(horseId: horse.uuid)
                    }
                }
            }
        }
        .onAppear {
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
                Image(systemName: "horse")
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
                        Image(systemName: "horse")
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
        let descriptor = FetchDescriptor<Horse>(
            predicate: #Predicate { $0.uuid == horseId }
        )
        
        if let loadedHorse = try? modelContext.fetch(descriptor).first {
            self.horse = loadedHorse
            self.findings = loadedHorse.notes ?? ""
            
            // Load body photos
            self.frontPhotoData = loadedHorse.frontPhotoData
            self.rightPhotoData = loadedHorse.rightPhotoData
            self.backPhotoData = loadedHorse.backPhotoData
            self.leftPhotoData = loadedHorse.leftPhotoData
            
            // Load abnormal photos
            self.abnormalPhotos = loadedHorse.abnormalPhotosData
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
        HorseInfoView(horseId: horse.uuid)
            .environmentObject(NavigationState())
    }
    .modelContainer(for: Horse.self, inMemory: true)
} 