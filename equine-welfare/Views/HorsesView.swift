import SwiftUI
import SwiftData

struct HorsesView: View {
    @EnvironmentObject private var navigationState: NavigationState
    @Environment(\.modelContext) private var modelContext
    
    // Get horses from the current assessment
    @Query private var assessments: [Assessment]
    
    var horses: [Horse] {
        if let currentAssessmentId = navigationState.currentAssessmentId,
           let assessment = assessments.first(where: { $0.id == currentAssessmentId }) {
            return assessment.horses
        }
        return []
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
                            HorseInfoRow(horse: horse, onTap: {
                                navigationState.showHorseInfo(horseId: horse.uuid)
                            })
                            
                            HorseNotesSection(horse: horse)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.white)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            deleteHorse(horses[index])
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color(.systemGray6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemGray6))
    }
    
    private func addHorse() {
        // Navigate to the horse detail screen without specifying a horse ID
        navigationState.showAddHorse()
    }
    
    private func deleteHorse(_ horse: Horse) {
        // Remove the horse from the current assessment
        if let currentAssessmentId = navigationState.currentAssessmentId,
           let assessment = assessments.first(where: { $0.id == currentAssessmentId }) {
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
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            // Horse image
            if let photoData = horse.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .padding(10)
                    .foregroundColor(.gray)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(horse.name), \(horse.age) \(horse.ageUnit.rawValue) old")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Text("Breed: \(horse.breed)")
                        .font(.caption)
                    
                    Text("Time on Farm: \(horse.timeOnFarm) \(horse.timeUnit.rawValue)")
                        .font(.caption)
                    
                    Text("Color: \(horse.color)")
                        .font(.caption)
                    
                    Text("Sex: \(horse.sex)")
                        .font(.caption)
                    
                    Text("BCS: \(String(format: "%.1f", horse.bcsScore))")
                        .font(.caption)
                }
            }
            
            Spacer()
            
            // Navigation chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
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
    HorsesView()
        .environmentObject(NavigationState())
        .modelContainer(for: Assessment.self, inMemory: true)
} 