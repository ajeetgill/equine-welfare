import SwiftData
import SwiftUI

// This wrapper view handles the navigation stack for Horses section
struct HorsesNavigationView: View {
    let assessmentId: UUID
    @Binding var parentNavigationPath: NavigationPath

    // State for explicit navigation
    @State private var currentView: HorseViewState = .list
    @State private var selectedHorseId: UUID? = nil

    var body: some View {
        NavigationStack {
            VStack {
                // Base layer - horse list
                if currentView == .list {
                    HorsesView(
                        assessmentId: assessmentId,
                        onSelectHorse: { horseId in
                            withAnimation {
                                selectedHorseId = horseId
                                currentView = .horseInfo
                            }
                        }
                    )
                    .disabled(currentView != .list)
                }
                // Horse Detail view (Add)
                if currentView == .addHorse {
                    HorseDetailView(
                        horseId: nil,
                        assessmentId: assessmentId,
                        onDismiss: {
                            withAnimation {
                                currentView = .list
                            }
                        }
                    )
                    .transition(.move(edge: .trailing))
                }
                // Horse Detail view (Edit)
                if currentView == .editHorse, let horseId = selectedHorseId {
                    HorseDetailView(
                        horseId: horseId,
                        assessmentId: assessmentId,
                        onDismiss: {
                            withAnimation {
                                currentView = .list
                            }
                        }
                    )
                    .transition(.move(edge: .leading))
                }

                // Horse Info view
                if currentView == .horseInfo, let horseId = selectedHorseId {
                    HorseInfoView(
                        horseId: horseId,
                        onEdit: { horseId, _ in
                            withAnimation {
                                selectedHorseId = horseId
                                currentView = .editHorse
                            }
                        }
                    )
                    .transition(.move(edge: .trailing))
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Back") {
                                withAnimation {
                                    currentView = .list
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(navTitle)
        }
        .toolbar {
            if currentView == .list {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        withAnimation {
                            selectedHorseId = nil
                            currentView = .addHorse
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }

    }
    private var navTitle: String {
        switch currentView {
        case .list:
            return "All Horses"  // Empty title when showing the list
        case .addHorse:
            return "Add Horse"
        case .horseInfo:
            return "Horse Details"  // Priority is given to Name of horse as Title, but this is a fallback title. No idea when/if we will need fallback, but for now just to be safe
        case .editHorse:
            return "Edit Horse"
        }

    }
}

// Navigation states for horses section
enum HorseViewState {
    case list
    case addHorse
    case horseInfo
    case editHorse
}

// Preview
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Assessment.self, Horse.self, configurations: config)

    // Create a sample assessment with horses
    let modelContext = container.mainContext
    let assessment = Assessment(
        vetName: "Dr. Smith", farmName: "Green Acres", visitDate: Date())

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

    return HorsesNavigationView(
        assessmentId: assessment.id,
        parentNavigationPath: .constant(NavigationPath())
    )
    .modelContainer(container)
}
