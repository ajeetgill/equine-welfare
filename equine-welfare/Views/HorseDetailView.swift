import SwiftUI
import SwiftData
import PhotosUI
import MijickCamera

struct HorseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let horseId: UUID?
    let assessmentId: UUID
    var onDismiss: (() -> Void)?
    
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
        onDismiss: (() -> Void)? = nil
    ) {
        self.horseId = horseId
        self.assessmentId = assessmentId
        self.onDismiss = onDismiss
        
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
            ToolbarItem(placement: .topBarTrailing) {
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

            let bcsScore = Int(horse.bcsScore)
            VStack(alignment: .leading, spacing: 12) {
                getBCSImage(for: bcsScore)
                    .frame(maxWidth: .infinity, alignment: .center)
                bcsDescriptionContent(for: bcsScore)
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
        print("DEBUG: Starting saveHorse() in HorseDetailView")
        
        Task { @MainActor in
            do {
                // Create a fresh descriptor for fetch with a more specific predicate
                let assessmentDescriptor = FetchDescriptor<Assessment>(
                    predicate: #Predicate { $0.id == assessmentId }
                )
                
                // Fetch the assessment with that exact ID
                let assessments = try modelContext.fetch(assessmentDescriptor)
                
                if assessments.isEmpty {
                    print("ERROR: No assessment found with ID \(assessmentId)")
                    
                    // Create a placeholder assessment with the expected ID
                    let placeholderAssessment = Assessment(
                        vetName: "Placeholder", 
                        farmName: "Placeholder", 
                        visitDate: Date()
                    )
                    placeholderAssessment.id = assessmentId  // Use the expected ID
                    modelContext.insert(placeholderAssessment)
                    
                    // Configure and insert the horse
                    if isNewHorse {
                        horse.uuid = UUID()
                        modelContext.insert(horse)
                    }
                    
                    // Set up BOTH sides of the relationship
                    horse.assessment = placeholderAssessment  // This is crucial!
                    placeholderAssessment.horses.append(horse)
                    
                    try modelContext.save()
                    print("DEBUG: Created placeholder assessment and saved horse with relationship")
                } else {
                    let assessment = assessments[0]
                    print("DEBUG: Found assessment: \(assessment.displayName) with ID: \(assessment.id)")
                    
                    if isNewHorse {
                        // Ensure we have a new UUID
                        horse.uuid = UUID()
                        
                        // Insert the horse into the context
                        modelContext.insert(horse)
                        
                        // Set up BOTH sides of the relationship
                        horse.assessment = assessment  // This is crucial!
                        assessment.horses.append(horse)
                        
                        print("DEBUG: Added to assessment, now has \(assessment.horses.count) horses")
                    } else {
                        print("DEBUG: Updating existing horse: \(horse.name)")
                        
                        // Ensure relationship is still correct for existing horse
                        if horse.assessment == nil || horse.assessment?.id != assessment.id {
                            horse.assessment = assessment
                            print("DEBUG: Fixed missing assessment relationship")
                        }
                    }
                    
                    // Save all changes
                    try modelContext.save()
                    print("DEBUG: Changes saved to database")
                }
                
                // Dismiss the view after saving
                dismissView()
                
            } catch {
                print("ERROR: Failed to save horse: \(error.localizedDescription)")
            }
        }
    }
    
    private func dismissView() {
        // Try both the environment dismiss and the onDismiss callback
        // First try the onDismiss callback
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            // Fallback to environment dismiss
            dismiss()
        }
    }
    
    private func loadHorse() {
        if let horseId = horseId {
            // Load the horse from the database
            do {
                let horseDescriptor = FetchDescriptor<Horse>(
                    predicate: #Predicate<Horse> { horse in
                        horse.uuid == horseId
                    }
                )
                
                if let loadedHorse = try modelContext.fetch(horseDescriptor).first {
                    horse = loadedHorse
                    isNewHorse = false
                    // Set the input values from the loaded horse
                    ageInput = loadedHorse.age > 0 ? loadedHorse.age : nil
                    timeOnFarmInput = loadedHorse.timeOnFarm > 0 ? loadedHorse.timeOnFarm : nil
                    
                    // Set the animal type based on the isHorse property
                    animalType = loadedHorse.isHorse ? .horse : .donkey
                } else {
                    print("ERROR: Could not find horse with ID: \(horseId)")
                }
            } catch {
                print("ERROR: Loading horse failed: \(error)")
            }
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
