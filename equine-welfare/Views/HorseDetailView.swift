import SwiftUI
import SwiftData
import PhotosUI

struct HorseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationState: NavigationState
    
    @State private var horse: Horse
    @State private var isNewHorse: Bool
    @State private var photoItem: PhotosUI.PhotosPickerItem?
    @State private var showBCSReferenceImage = false
    
    // Use the shared instance instead of creating a new one
    private let bcsManager = BCSManager.shared
    
    // Color and sex options
    private let colorOptions = ["Albino", "Appaloosa", "Apricot", "Bay", "Bay Dun", "Bay Overo", "Bay Roan", "Bay Tobiano", "Bay Tovero", "Bay w/Blanket", "Bay/White", "Black", "Black Bay", "Blackgrey", "Black Overo", "Black Roan", "Black Tobiano", "Black Tovero", "Black w/Blanket", "Black/White", "Blonde", "Blond/Sorrel", "Blue Roan", "Blue Roan Overo", "Blue Roan Tobiano", "Blue Roan w/Blanket", "Brown", "Brown Dun", "Brown/White", "Buckskin", "Buckskin/Grulla", "Buckskin Overo", "Buckskin Tobiano", "Buckskin w/Blanket", "Buckskin/White", "Caramel", "Champagne", "Chestnut", "Chestnut Overo", "Chestnut Roan", "Chestnut Tobiano", "Chestnut w/Blanket", "Chestnut/White", "Chocolate", "Chocolate/Palomino", "Chocolate/White", "Cream", "Cremella", "Cremello", "Dapple", "Dapple Gray", "Dark Bay", "Dark Bay Blue Roan", "Dark Bay/Brown", "Dark Bay/White", "Dark Brown", "Dark Dun", "Double Dapple", "Dun", "Dunalino", "Dun Overo", "Dun Tobiano", "Dun w/Blanket", "Dun/White", "Flea Bitten Grey", "Gray", "Gray w/Blanket", "Gray/White", "Grey", "Grey Dapple", "Grey Dun", "Grey/White", "Grulla", "Grulla/White", "Grullo", "Grullo Champagne", "Grullo Overo", "Grullo/White", "Leopard", "Lineback Dun", "Liver", "Liver Chestnut", "Liver Chestnut w/Blanket", "Overo", "Paint", "Palomino", "Palomino Overo", "Palomino/Tobiano", "Palomino w/Blanket", "Palomino/White", "Perlino", "Piebald", "Pinto", "Raicano", "Red Chocolate", "Red Dun", "Red Dun w/Blanket", "Red Roan", "Red Roan Overo", "Red Roan Tobiano", "Red Roan w/Blanket", "Red Snowflake", "Roan", "Roan Bay", "Roan Buckskin", "Roan Chestnut", "Roan Strawberry", "Roan/White", "Sable", "Seal Bay", "Seal Brown", "Silver", "Silver Dapple", "Silver Dapple Pinto", "Sorrel", "Sorrel Overo", "Sorrel Tobiano", "Sorrel/Tovero", "Sorrel w/Blanket", "Sorrel/White", "Strawberry Roan", "Tobiano", "Tri", "White"]
    private let sexOptions = ["Mare", "Stallion", "Gelding"]
    private let breedOptions = ["Quarter Horse", "Appendix Quarter Horse", "Quarter Horse cross", "Standardbred", "Pony", "Halflinger", "Paint", "Appaloosa", "Miniature Horse", "Percheron", "Belgian", "Clydesdale", "Hannoverian", "Warmblood", "Warmblood cross", "Draft cross", "Arabian", "Arabian cross", "Thoroughbred", "Thoroughbred cross", "Saddlebred", "Morgan", "Cross", "Donkey", "Unknown"]
    
    init(horse: Horse? = nil) {
        let newHorse = horse ?? Horse(
            name: "",
            age: 0,
            color: "Bay",
            sex: "Gelding",
            breed: "Quarter Horse",
            timeOnFarm: 0,
            bcsScore: 3.0
        )
        
        _horse = State(initialValue: newHorse)
        _isNewHorse = State(initialValue: horse == nil)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Photo section at top
                HStack {
                    Spacer()
                    photoSection
                    Spacer()
                }
                .padding(.bottom, 16)
                
                // Form-style layout with simplified design
                VStack(alignment: .center, spacing: 24) {
                    // ALL FIELDS USING IDENTICAL STRUCTURE
                    
                    // Name field
                    HStack {
                        Text("Name")
                            .font(.headline)    
                            .frame(width: 120, alignment: .leading)
                        
                        Spacer()
                        
                        TextField("Horse name", text: $horse.name)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 200)
                    }
                    .frame(maxWidth: 500)
                    
                    // Age field
                    HStack {
                        Text("Age")
                            .font(.headline)
                            .frame(width: 120, alignment: .leading)
                        
                        Spacer()
                        
                        // Number input field with fixed width
                        TextField("Age", value: $horse.age, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        // Unit selection dropdown
                        Menu {
                            ForEach(AgeUnit.allCases, id: \.self) { unit in
                                Button(unit.rawValue) {
                                    horse.ageUnit = unit
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(horse.ageUnit.rawValue)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    .frame(maxWidth: 500)
                    
                    // Color field
                    HStack {
                        Text("Color")
                            .font(.headline)
                            .frame(width: 120, alignment: .leading)
                        
                        Spacer()
                        
                        TextField("Color", text: $horse.color)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 150, alignment: .trailing)
                        
                        Menu {
                            ForEach(colorOptions, id: \.self) { color in
                                Button(color) {
                                    horse.color = color
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .padding(.horizontal, 8)
                        }
                    }
                    .frame(maxWidth: 500)
                    
                    // Sex field
                    HStack {
                        Text("Sex")
                            .font(.headline)
                            .frame(width: 120, alignment: .leading)
                        
                        Spacer()
                        
                        TextField("Sex", text: $horse.sex)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 150, alignment: .trailing)
                        
                        Menu {
                            ForEach(sexOptions, id: \.self) { sex in
                                Button(sex) {
                                    horse.sex = sex
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .padding(.horizontal, 8)
                        }
                    }
                    .frame(maxWidth: 500)
                    
                    // Breed field
                    HStack {
                        Text("Breed")
                            .font(.headline)
                            .frame(width: 120, alignment: .leading)
                        
                        Spacer()
                        
                        TextField("Breed", text: $horse.breed)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 150, alignment: .trailing)
                        
                        Menu {
                            ForEach(breedOptions, id: \.self) { breed in
                                Button(breed) {
                                    horse.breed = breed
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .padding(.horizontal, 8)
                        }
                    }
                    .frame(maxWidth: 500)
                    
                    // Time on Farm field
                    HStack {
                        Text("Time on Farm")
                            .font(.headline)
                            .frame(width: 120, alignment: .leading)
                        
                        Spacer()
                        
                        // Number input field with fixed width
                        TextField("Time", value: $horse.timeOnFarm, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        // Unit selection dropdown
                        Menu {
                            ForEach(TimeUnit.allCases, id: \.self) { unit in
                                Button(unit.rawValue) {
                                    horse.timeUnit = unit
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(horse.timeUnit.rawValue)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    .frame(maxWidth: 500)
                    
                    // BCS Section with modern styling
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack {
                            Text("BCS Score")
                                .font(.headline)
                                .frame(width: 120, alignment: .leading)
                            
                            Button(action: {
                                // Show the BCS score reference image
                                showBCSReferenceImage.toggle()
                            }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                            }
                            .sheet(isPresented: $showBCSReferenceImage) {
                                VStack {
                                    Text("Body Condition Score Reference")
                                        .font(.headline)
                                        .padding()
                                    
                                    Image("labelled-horse")
                                        .resizable()
                                        .scaledToFit()
                                        .padding()
                                    
                                    Button("Close") {
                                        showBCSReferenceImage = false
                                    }
                                    .padding()
                                }
                            }
                            
                        }
                        
                        // Slider for BCS score
                        HStack {
                            Text("1")
                            Slider(value: $horse.bcsScore, in: 1...9, step: 0.5)
                            Text("9")
                        }
                        
                        Text("Score: \(String(format: "%.1f", horse.bcsScore))")
                            .foregroundColor(.blue)
                        
                        // BCS Image and Description in a centered card
                        HStack {
                            // Center the card
                            Spacer()
                            
                            // Card with image and description side by side with fixed width
                            HStack(alignment: .top, spacing: 20) {
                                // Left side: BCS image with fixed width and centered
                                let bcsScore = Int(horse.bcsScore)
                                VStack {
                                    bcsManager.getBCSImage(for: bcsScore)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 220, height: 220)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .padding(.vertical)
                                .padding(.horizontal)
                                
                                // Right side: BCS description
                                if let bcsBodyParts = bcsManager.getBCSData(for: bcsScore), !bcsBodyParts.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("BCS \(bcsScore) Description")
                                            .font(.headline)
                                            .padding(.bottom, 4)
                                        
                                        // Create a structured layout with part names on left and descriptions on right
                                        ForEach(bcsBodyParts) { part in
                                            HStack(alignment: .top, spacing: 16) {
                                                // Left side - Part name
                                                Text(part.name)
                                                    .font(.body)
                                                    .foregroundColor(.gray)
                                                    .frame(width: 150, alignment: .leading)
                                                
                                                // Right side - Bullet descriptions
                                                VStack(alignment: .leading, spacing: 6) {
                                                    ForEach(part.descriptions, id: \.self) { description in
                                                        HStack(alignment: .top, spacing: 4) {
                                                            Text("•")
                                                                .foregroundColor(.gray)
                                                            Text(description)
                                                                .font(.body)
                                                                .foregroundColor(.gray)
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                    .padding()
                                    .frame(width: 500, alignment: .leading)
                                } else {
                                    VStack(alignment: .leading) {
                                        Text("BCS \(bcsScore) Description")
                                            .font(.headline)
                                            
                                            Text("No description data available for BCS \(bcsScore)")
                                                .foregroundColor(.secondary)
                                                .italic()
                                    }
                                    .padding()
                                    .frame(width: 500, alignment: .leading)
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(8)
                            
                            // Center the card
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Save button
                    Button(action: saveHorse) {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle(isNewHorse ? "Add Horse" : "Edit Horse")
        .background(Color(.systemGray6))
    }
    
    private var photoSection: some View {
        VStack {
            // Horse image placeholder
            if let photoData = horse.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .padding(20)
                    .foregroundColor(.gray)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Upload photo button
            PhotosPicker(selection: $photoItem, matching: .images) {
                Text("Upload Photo")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        horse.photoData = data
                    }
                }
            }
        }
    }
    
    private func saveHorse() {
        if isNewHorse {
            modelContext.insert(horse)
            
            // Add to current assessment
            if let assessmentId = navigationState.currentAssessmentId,
               let assessment = try? modelContext.fetch(
                FetchDescriptor<Assessment>(predicate: #Predicate { $0.id == assessmentId })
               ).first {
                assessment.horses.append(horse)
                try? modelContext.save()
            }
        }
        
        try? modelContext.save()
        navigationState.showHorses()
    }
}

// Helper views - keeping these intact
struct FormField<Content: View>: View {
    let label: String
    let alignment: HorizontalAlignment
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(label)
                .font(.headline)
                .foregroundColor(.primary)
            
            content()
        }
    }
}

struct BCSPartView: View {
    let part: BCSBodyPart
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(part.name)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            ForEach(part.descriptions, id: \.self) { description in
                HStack(alignment: .top, spacing: 4) {
                    Text("•")
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    HorseDetailView()
        .environmentObject(NavigationState())
        .modelContainer(for: Horse.self, inMemory: true)
} 
