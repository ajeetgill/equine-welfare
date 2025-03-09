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
        VStack(alignment: .leading) {
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
                VStack {
                    Spacer()
                    Text("No horses added yet")
                        .foregroundColor(.gray)
                        .italic()
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(horses) { horse in
                            HorseListItem(horse: horse)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    navigationState.showHorseDetail(horseId: horse.uuid)
                                }
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemGray6))
    }
    
    private func addHorse() {
        // Navigate to the horse detail screen without specifying a horse ID
        navigationState.showAddHorse()
    }
}

struct HorseListItem: View {
    let horse: Horse
    
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
                Image(systemName: "horse")
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
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}

#Preview {
    HorsesView()
        .environmentObject(NavigationState())
        .modelContainer(for: Assessment.self, inMemory: true)
} 