import SwiftUI
import SwiftData
import PhotosUI
import MijickCamera

struct HorseDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let horseId: UUID?
    let assessmentId: UUID
    /// Called after a successful save with the saved horse's id. Cancelling the
    /// enclosing sheet never calls this, so the working copy is simply discarded.
    var onSaved: (UUID) -> Void = { _ in }
    
    @State private var horse: Horse
    @State private var isNewHorse: Bool
    @State private var photoItem: PhotosUI.PhotosPickerItem?
    @State private var showBCSReferenceImage = false
    @State private var ageInput: Int?
    @State private var timeOnFarmInput: Int?
    @State private var showingMediaPicker = false
    @State private var animalType: AnimalType = .horse
    
    // Animal type enum for segmented control
    enum AnimalType: String, CaseIterable {
        case horse = "Horse"
        case donkey = "Donkey"
    }
    
    // Use the shared instance instead of creating a new one
    private let bcsManager = BCSManager.shared
    private let donkeyBCSManager = BCSManager.donkey
    
    // Color and sex options
    private let colorOptions = ["Albino", "Appaloosa", "Apricot", "Bay", "Bay Dun", "Bay Overo", "Bay Roan", "Bay Tobiano", "Bay Tovero", "Bay w/Blanket", "Bay/White", "Black", "Black Bay", "Blackgrey", "Black Overo", "Black Roan", "Black Tobiano", "Black Tovero", "Black w/Blanket", "Black/White", "Blonde", "Blond/Sorrel", "Blue Roan", "Blue Roan Overo", "Blue Roan Tobiano", "Blue Roan w/Blanket", "Brown", "Brown Dun", "Brown/White", "Buckskin", "Buckskin/Grulla", "Buckskin Overo", "Buckskin Tobiano", "Buckskin w/Blanket", "Buckskin/White", "Caramel", "Champagne", "Chestnut", "Chestnut Overo", "Chestnut Roan", "Chestnut Tobiano", "Chestnut w/Blanket", "Chestnut/White", "Chocolate", "Chocolate/Palomino", "Chocolate/White", "Cream", "Cremella", "Cremello", "Dapple", "Dapple Gray", "Dark Bay", "Dark Bay Blue Roan", "Dark Bay/Brown", "Dark Bay/White", "Dark Brown", "Dark Dun", "Double Dapple", "Dun", "Dunalino", "Dun Overo", "Dun Tobiano", "Dun w/Blanket", "Dun/White", "Flea Bitten Grey", "Gray", "Gray w/Blanket", "Gray/White", "Grey", "Grey Dapple", "Grey Dun", "Grey/White", "Grulla", "Grulla/White", "Grullo", "Grullo Champagne", "Grullo Overo", "Grullo/White", "Leopard", "Lineback Dun", "Liver", "Liver Chestnut", "Liver Chestnut w/Blanket", "Overo", "Paint", "Palomino", "Palomino Overo", "Palomino/Tobiano", "Palomino w/Blanket", "Palomino/White", "Perlino", "Piebald", "Pinto", "Raicano", "Red Chocolate", "Red Dun", "Red Dun w/Blanket", "Red Roan", "Red Roan Overo", "Red Roan Tobiano", "Red Roan w/Blanket", "Red Snowflake", "Roan", "Roan Bay", "Roan Buckskin", "Roan Chestnut", "Roan Strawberry", "Roan/White", "Sable", "Seal Bay", "Seal Brown", "Silver", "Silver Dapple", "Silver Dapple Pinto", "Sorrel", "Sorrel Overo", "Sorrel Tobiano", "Sorrel/Tovero", "Sorrel w/Blanket", "Sorrel/White", "Strawberry Roan", "Tobiano", "Tri", "White"]
    private let sexOptions = ["Mare", "Stallion", "Gelding"]
    private let breedOptions = ["Quarter Horse", "Appendix Quarter Horse", "Quarter Horse cross", "Standardbred", "Pony", "Halflinger", "Paint", "Appaloosa", "Miniature Horse", "Percheron", "Belgian", "Clydesdale", "Hannoverian", "Warmblood", "Warmblood cross", "Draft cross", "Arabian", "Arabian cross", "Thoroughbred", "Thoroughbred cross", "Saddlebred", "Morgan", "Cross", "Donkey", "Unknown"]
    
    init(
        horseId: UUID?,
        assessmentId: UUID,
        onSaved: @escaping (UUID) -> Void = { _ in }
    ) {
        self.horseId = horseId
        self.assessmentId = assessmentId
        self.onSaved = onSaved
        
        // Initialize default horse
        let initialHorse = Horse(
            name: "",
            age: 0,
            color: "",
            sex: "",
            breed: "",
            timeOnFarm: 0,
            bcsScore: 4.0,
            isHorse: true  // Explicitly set isHorse property
        )
        
        self._horse = State(initialValue: initialHorse)
        self._isNewHorse = State(initialValue: horseId == nil)
        self._ageInput = State(initialValue: nil)
        self._timeOnFarmInput = State(initialValue: nil)
        
        // Note: We'll load the actual horse in onAppear if horseId is provided
    }
    
    var body: some View {
        Form {
            SwiftUI.Section {
                HStack {
                    Spacer()
                    photoSection
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            SwiftUI.Section("Identity") {
                LabeledContent("Name") {
                    TextField("Horse name", text: $horse.name)
                        .multilineTextAlignment(.trailing)
                }
                PickerOrCustomField(label: "Breed", options: breedOptions, value: $horse.breed)
                PickerOrCustomField(label: "Color", options: colorOptions, value: $horse.color)
                PickerOrCustomField(label: "Sex", options: sexOptions, value: $horse.sex)
            }

            SwiftUI.Section("Age & Tenure") {
                LabeledContent("Age") {
                    HStack(spacing: 12) {
                        TextField("0", value: $ageInput, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .onChange(of: ageInput) { _, newValue in
                                horse.age = newValue ?? 0
                            }
                        Picker("Age unit", selection: $horse.ageUnit) {
                            ForEach(AgeUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .labelsHidden()
                    }
                }
                LabeledContent("Time on Farm") {
                    HStack(spacing: 12) {
                        TextField("0", value: $timeOnFarmInput, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .onChange(of: timeOnFarmInput) { _, newValue in
                                horse.timeOnFarm = newValue ?? 0
                            }
                        Picker("Time unit", selection: $horse.timeUnit) {
                            ForEach(TimeUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            bcsSection
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveHorse)
                    .disabled(horse.name.isEmpty)
            }
        }
        .sheet(isPresented: $showBCSReferenceImage) {
            bcsReferenceSheet
        }
        .onAppear {
            // If we have a horse ID, load the existing horse
            loadHorse()
        }
    }

    /// Body Condition Score — the core of the assessment, so it gets its own
    /// section with a large live readout, the animal-type toggle, and the
    /// per-score reference description.
    @ViewBuilder
    private var bcsSection: some View {
        SwiftUI.Section("Body Condition Score") {
            Picker("Animal Type", selection: $animalType) {
                ForEach(AnimalType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: animalType) { _, newValue in
                // Donkeys use a 1–5 scale; cap an over-range score when switching.
                if newValue == .donkey && horse.bcsScore > 5 {
                    horse.bcsScore = 5
                }
                horse.isHorse = (newValue == .horse)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Score")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f", horse.bcsScore))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                }
                HStack {
                    Text("1")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(
                        value: $horse.bcsScore,
                        in: 1...(animalType == .horse ? 9 : 5),
                        step: 0.5
                    )
                    Text(animalType == .horse ? "9" : "5")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            Button {
                showBCSReferenceImage.toggle()
            } label: {
                Label("View BCS Reference Chart", systemImage: "info.circle")
            }

            // Image and description sit side-by-side so they stay compact
            // enough to remain on screen together with the slider above — the
            // reviewer can drag the slider and watch the description update.
            let bcsScore = Int(horse.bcsScore)
            HStack(alignment: .top, spacing: 16) {
                getBCSImage(for: bcsScore)
                    .frame(width: 180)
                VStack(alignment: .leading, spacing: 12) {
                    bcsDescriptionContent(for: bcsScore)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
        }
    }

    private var bcsReferenceSheet: some View {
        NavigationStack {
            ScrollView {
                Image(animalType == .horse ? "labelled-horse" : "labelled-donkey")
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
            .navigationTitle("BCS Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showBCSReferenceImage = false }
                }
            }
        }
    }
    
    private var photoSection: some View {
        VStack {
            // Horse image placeholder
            if let photoData = horse.photoData, let uiImage = UIImage(data: photoData.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                     .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image("horse-icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .grayscale(1)
                    .padding(20)
                    .foregroundColor(.gray)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
                MediaPicker(isPresented: $showingMediaPicker, cameraText: "", galleryText: "") {
                    mediaData, mediaType in
                    let attachment =
                        mediaType == .image
                        ? MediaAttachment(imageData: mediaData)
                        : MediaAttachment(videoData: mediaData)
                    horse.photoData = attachment
                }
                .cornerRadius(30)
                .background(Color(.systemGray6).opacity(0.2))
        }
    }
    
    private func saveHorse() {
        do {
            let assessmentDescriptor = FetchDescriptor<Assessment>(
                predicate: #Predicate { $0.id == assessmentId }
            )
            guard let assessment = try modelContext.fetch(assessmentDescriptor).first else {
                print("ERROR: No assessment found with ID \(assessmentId)")
                return
            }

            if isNewHorse {
                // `horse` is a fresh detached instance — insert and link it.
                modelContext.insert(horse)
                horse.assessment = assessment
                assessment.horses.append(horse)
            } else {
                // `horse` is a working copy; apply its edited fields to the
                // persisted horse. (Cancel never reaches here, so its edits are
                // discarded along with the working copy.)
                let id = horse.uuid
                let horseDescriptor = FetchDescriptor<Horse>(
                    predicate: #Predicate<Horse> { $0.uuid == id }
                )
                guard let persisted = try modelContext.fetch(horseDescriptor).first else {
                    print("ERROR: Could not find horse to update: \(id)")
                    return
                }
                apply(horse, to: persisted)
            }

            try modelContext.save()
            onSaved(horse.uuid)
        } catch {
            print("ERROR: Failed to save horse: \(error.localizedDescription)")
        }
    }

    /// Copies the form-editable fields from a working copy onto the persisted
    /// horse. Fields the form doesn't touch (notes, directional photos, …) are
    /// left untouched.
    private func apply(_ source: Horse, to target: Horse) {
        target.name = source.name
        target.age = source.age
        target.color = source.color
        target.sex = source.sex
        target.breed = source.breed
        target.otherBreed = source.otherBreed
        target.timeOnFarm = source.timeOnFarm
        target.bcsScore = source.bcsScore
        target.ageUnit = source.ageUnit
        target.timeUnit = source.timeUnit
        target.isHorse = source.isHorse
        target.photoData = source.photoData
    }

    private func loadHorse() {
        guard let horseId else { return }
        do {
            let horseDescriptor = FetchDescriptor<Horse>(
                predicate: #Predicate<Horse> { $0.uuid == horseId }
            )
            guard let loaded = try modelContext.fetch(horseDescriptor).first else {
                print("ERROR: Could not find horse with ID: \(horseId)")
                return
            }

            // Edit against a detached working copy so the persisted horse is
            // untouched until Save. Keep the same uuid so Save can re-fetch it.
            let working = Horse(
                name: loaded.name,
                age: loaded.age,
                color: loaded.color,
                sex: loaded.sex,
                breed: loaded.breed,
                otherBreed: loaded.otherBreed,
                timeOnFarm: loaded.timeOnFarm,
                bcsScore: loaded.bcsScore,
                photoData: loaded.photoData,
                notes: loaded.notes,
                ageUnit: loaded.ageUnit,
                timeUnit: loaded.timeUnit,
                isHorse: loaded.isHorse
            )
            working.uuid = loaded.uuid
            horse = working
            isNewHorse = false
            ageInput = loaded.age > 0 ? loaded.age : nil
            timeOnFarmInput = loaded.timeOnFarm > 0 ? loaded.timeOnFarm : nil
            animalType = loaded.isHorse ? .horse : .donkey
        } catch {
            print("ERROR: Loading horse failed: \(error)")
        }
    }
    
    // Helper method to get the appropriate BCS image
    private func getBCSImage(for score: Int) -> some View {
        let adjustedScore = getAdjustedBCSScore(score: horse.bcsScore)
        if animalType == .horse {
            return bcsManager.getBCSImage(for: adjustedScore)
                .resizable()
                .scaledToFit()
        } else {
            return donkeyBCSManager.getBCSImage(for: adjustedScore)
                .resizable()
                .scaledToFit()
        }
    }
    
    // Helper method to get the BCS description content
    private func bcsDescriptionContent(for score: Int) -> some View {
        Group {
            if animalType == .horse {
                horseBCSDescription(for: score)
            } else {
                donkeyBCSDescription(for: score)
            }
        }
    }
    
    // Helper function to handle special BCS score rounding
    private func getAdjustedBCSScore(score: Double) -> Int {
        let intScore = Int(score)
        let fraction = score - Double(intScore)
        
        if fraction == 0.5 {
            if animalType == .horse && score > 6 {
                return intScore + 1
            } else if animalType == .donkey && score > 3 {
                return intScore + 1
            }
        }
        
        return intScore
    }
    
    // Horse-specific BCS description
    private func horseBCSDescription(for score: Int) -> some View {
        let adjustedScore = getAdjustedBCSScore(score: horse.bcsScore)
        return Group {
            if let bcsBodyParts = bcsManager.getBCSData(for: adjustedScore), !bcsBodyParts.isEmpty {
                ForEach(bcsBodyParts) { part in
                    BCSPartView(part: part)
                }
            } else {
                Text("No description data available")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // Donkey-specific BCS description
    private func donkeyBCSDescription(for score: Int) -> some View {
        let adjustedScore = getAdjustedBCSScore(score: horse.bcsScore)
        return Group {
            if let donkeyBodyParts = donkeyBCSManager.getBCSData(for: adjustedScore), !donkeyBodyParts.isEmpty {
                ForEach(donkeyBodyParts) { part in
                    BCSPartView(part: part)
                }
            } else {
                Text("No description data available")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct BCSPartView: View {
    let part: BCSBodyPart
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(part.name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ForEach(part.descriptions, id: \.self) { description in
                HStack(alignment: .top, spacing: 4) {
                    Text("• \(description)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.bottom, 2)
    }
}

/// A form row that lets the user pick a value from a known list *or* type a
/// custom one. Choosing "Other…" reveals a free-text field pre-filled with any
/// existing custom value. Used for fields (Color, Sex, Breed) that have a
/// canonical list but must still accept anything the field vet enters.
private struct PickerOrCustomField: View {
    let label: String
    let options: [String]
    @Binding var value: String

    /// Sentinel tag for the "Other…" menu entry (won't collide with real data).
    private static let customTag = "\u{2063}__other__"

    /// The stored value is custom when it's non-empty and not a known option.
    private var valueIsCustom: Bool {
        !value.isEmpty && !options.contains(value)
    }

    /// Set once the user explicitly picks "Other…", so the text field appears
    /// even before they've typed anything.
    @State private var choseOther = false

    private var showsCustomField: Bool { choseOther || valueIsCustom }

    var body: some View {
        Picker(label, selection: selection) {
            Text("None").tag("")
            ForEach(options, id: \.self) { option in
                Text(option).tag(option)
            }
            Text("Other…").tag(Self.customTag)
        }

        if showsCustomField {
            TextField("Enter \(label.lowercased())", text: $value)
                .multilineTextAlignment(.trailing)
        }
    }

    /// Maps the stored string to/from the picker's selection: a custom value (or
    /// an explicit "Other…" pick) resolves to the sentinel tag.
    private var selection: Binding<String> {
        Binding(
            get: { showsCustomField ? Self.customTag : value },
            set: { newValue in
                if newValue == Self.customTag {
                    choseOther = true
                } else {
                    choseOther = false
                    value = newValue
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        HorseDetailView(
            horseId: nil,
            assessmentId: UUID()
        )
    }
    .modelContainer(for: Horse.self, inMemory: true)
} 
