import SwiftData
import SwiftUI
import os

struct HorsesView: View {
    @Environment(\.modelContext) private var modelContext

    let assessmentId: UUID
    /// The horse currently shown in the detail column (for row highlighting).
    var selectedHorseId: UUID?
    var onSelectHorse: (UUID) -> Void

    // Get horses from the current assessment
    @Query private var assessments: [Assessment]

    init(
        assessmentId: UUID,
        selectedHorseId: UUID? = nil,
        onSelectHorse: @escaping (UUID) -> Void = { _ in }
    ) {
        self.assessmentId = assessmentId
        self.selectedHorseId = selectedHorseId
        self.onSelectHorse = onSelectHorse

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
        assessments.first?.horses ?? []
    }

    var body: some View {
        Group {
            if horses.isEmpty {
                ContentUnavailableView(
                    "No Horses Yet",
                    systemImage: "pawprint",
                    description: Text("Tap the + button to add the first horse.")
                )
            } else {
                List {
                    ForEach(horses) { horse in
                        Button {
                            onSelectHorse(horse.uuid)
                        } label: {
                            HorseRow(
                                horse: horse,
                                isSelected: horse.uuid == selectedHorseId
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            horse.uuid == selectedHorseId
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear
                        )
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            deleteHorse(horses[index])
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(
            maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading
        )
    }

    private func deleteHorse(_ horse: Horse) {
        do {
            try HorseStore(modelContext: modelContext)
                .delete(horse, fromAssessment: assessmentId)
        } catch {
            Logger.persistence.error(
                "Failed to delete horse: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

/// A compact, scannable row for the horses master list: thumbnail, name, a
/// one-line summary, and a BCS badge.
struct HorseRow: View {
    let horse: Horse
    var isSelected: Bool = false

    private var displayName: String {
        horse.name.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Unnamed \(horse.isHorse ? "Horse" : "Donkey")"
            : horse.name
    }

    /// e.g. "Horse · 4 years · Stallion"
    private var summary: String {
        [
            horse.isHorse ? "Horse" : "Donkey",
            "\(horse.age) \(horse.ageUnit.rawValue)",
            horse.sex,
        ]
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    /// e.g. "Standardbred · Bay"
    private var descriptors: String {
        [horse.breed, horse.color]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var bcsText: String {
        "\(String(format: "%.1f", horse.bcsScore))/\(horse.isHorse ? "9" : "5")"
    }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !descriptors.isEmpty {
                    Text(descriptors)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            bcsBadge
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let photoData = horse.photoData,
           let uiImage = UIImage(data: photoData.data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image("horse-icon")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .padding(9)
                .frame(width: 46, height: 46)
                .foregroundStyle(.secondary)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var bcsBadge: some View {
        VStack(spacing: 0) {
            Text("BCS")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(bcsText)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tintColor).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

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

    return HorsesPaneView(
        assessmentId: assessment.id
    )
    .modelContainer(container)
}
