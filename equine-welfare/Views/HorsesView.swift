import SwiftData
import SwiftUI

struct HorsesView: View {
    @Environment(\.modelContext) private var modelContext
    
    let assessmentId: UUID
    @Binding var navigationPath: NavigationPath

    // Get horses from the current assessment
    @Query private var assessments: [Assessment]

    init(assessmentId: UUID, navigationPath: Binding<NavigationPath>) {
        print("DEBUG: Initializing HorsesView with assessmentId: \(assessmentId)")
        self.assessmentId = assessmentId
        self._navigationPath = navigationPath
        
        // Initialize the Query with proper descriptor and sorting for Swift 6
        var descriptor = FetchDescriptor<Assessment>(
            predicate: #Predicate { $0.id == assessmentId }
        )
        
        // Add sorting as a separate step for Swift 6
        descriptor.sortBy = [SortDescriptor(\.visitDate, order: .reverse)]
        descriptor.fetchLimit = 1
        
        self._assessments = Query(descriptor)
    }

    var horses: [Horse] {
        // More direct approach - just return the horses from the first assessment
        let result = assessments.first?.horses ?? []
        print("DEBUG: HorsesView.horses computed property returning \(result.count) horses")
        if let first = assessments.first {
            print("DEBUG: Assessment found with ID: \(first.id)")
            print("DEBUG: Assessment contains \(first.horses.count) horses")
        } else {
            print("DEBUG: No assessment found with ID: \(assessmentId)")
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Horses")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button(action: addHorse) {
                    Label("Add Horse", systemImage: "plus")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()

            if horses.isEmpty {
                Spacer()
                Text("No horses added yet")
                    .foregroundColor(.gray)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                List {
                    ForEach(horses) { horse in
                        VStack(alignment: .leading, spacing: 0) {
                            NavigationLink(value: horse.uuid) {
                                HorseInfoRow(horse: horse)
                            }
                            HorseNotesSection(horse: horse)
                        }
                        .padding(.bottom, 20)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            deleteHorse(horses[index])
                        }
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading
        )
        .navigationDestination(for: UUID.self) { horseId in
            HorseInfoView(horseId: horseId, navigationPath: $navigationPath)
        }
        .navigationDestination(for: AppDestination.self) { destination in
            switch destination {
            case .horseDetail(let horseId, let correctAssessmentId):
                HorseDetailView(
                    horseId: horseId,
                    assessmentId: correctAssessmentId,
                    navigationPath: $navigationPath
                )
            default:
                EmptyView()
            }
        }
    }

    private func addHorse() {
        print("DEBUG: addHorse() called in HorsesView with assessmentId: \(assessmentId)")
        
        // Check if we have the assessment loaded correctly
        if let actualAssessment = assessments.first {
            print("DEBUG: Found actual assessment with ID: \(actualAssessment.id)")
            
            // Pass both the horse ID (nil for new) and the correct assessment ID
            navigationPath.append(AppDestination.horseDetail(horseId: nil, assessmentId: actualAssessment.id))
            
            print("DEBUG: Added horse detail with assessment ID: \(actualAssessment.id)")
        } else {
            print("ERROR: Couldn't find assessment when trying to add horse")
        }
    }

    private func deleteHorse(_ horse: Horse) {
        // Remove the horse from the current assessment
        if let assessment = assessments.first(where: { $0.id == assessmentId }) {
            if let index = assessment.horses.firstIndex(where: { $0.uuid == horse.uuid }) {
                assessment.horses.remove(at: index)
            }
        }

        // Delete the horse from the database
        modelContext.delete(horse)
        try? modelContext.save()
    }
}

// Horse info row - tappable to navigate to horse details
struct HorseInfoRow: View {
    let horse: Horse

    var body: some View {
        HStack {
            // Horse image
            if let photoData = horse.photoData,
                let uiImage = UIImage(data: photoData)
            {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFill()
                    .padding(10)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "\(horse.name), \(horse.age) \(horse.ageUnit.rawValue) old"
                )
                .font(.headline)

                HStack(spacing: 12) {
                    Text("Breed: \(horse.breed)")
                        .font(.caption)

                    Text(
                        "Time on Farm: \(horse.timeOnFarm) \(horse.timeUnit.rawValue)"
                    )
                    .font(.caption)

                    Text("Color: \(horse.color)")
                        .font(.caption)

                    Text("Sex: \(horse.sex)")
                        .font(.caption)

                    Text("BCS: \(String(format: "%.1f", horse.bcsScore))")
                        .font(.caption)
                }
            }
        }
        
        .contentShape(Rectangle())
        .padding(.vertical, 8)
    }
}

// Horse notes section - not tappable for navigation
struct HorseNotesSection: View {
    let horse: Horse
    @Environment(\.modelContext) private var modelContext
    @State private var isEditingNotes = false
    @State private var notes: String

    init(horse: Horse) {
        self.horse = horse
        self._notes = State(initialValue: horse.notes ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Findings or Extra Details")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if isEditingNotes {
                    Button("Done") {
                        isEditingNotes = false
                        saveNotes(notes)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }

            if isEditingNotes {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .onChange(of: notes) { _, newValue in
                        saveNotes(newValue)
                    }
            } else {
                Text(notes.isEmpty ? "Tap to add notes" : notes)
                    .font(.caption)
                    .foregroundColor(notes.isEmpty ? .gray : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .onTapGesture {
                        isEditingNotes = true
                    }
            }
        }
        .padding(.top, 4)
    }

    private func saveNotes(_ newNotes: String) {
        horse.notes = newNotes
        try? modelContext.save()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Assessment.self, Horse.self, configurations: config)
    
    // Create a sample assessment with horses
    let modelContext = container.mainContext
    let assessment = Assessment(vetName: "Dr. Smith", farmName: "Green Acres", visitDate: Date())
    
    // Add sample horses
    let horse1 = Horse(
        name: "Thunder",
        age: 5,
        color: "Bay",
        sex: "Gelding",
        breed: "Quarter Horse",
        timeOnFarm: 12,
        bcsScore: 3.5,
        notes: "Healthy and active"
    )
    
    let horse2 = Horse(
        name: "Misty",
        age: 8,
        color: "Gray",
        sex: "Mare",
        breed: "Arabian",
        timeOnFarm: 24,
        bcsScore: 4.0,
        notes: "Slight lameness in left front leg"
    )
    
    assessment.horses.append(horse1)
    assessment.horses.append(horse2)
    
    modelContext.insert(assessment)
    
    return NavigationStack {
        HorsesView(
            assessmentId: assessment.id,
            navigationPath: .constant(NavigationPath())
        )
    }
    .modelContainer(container)
}
