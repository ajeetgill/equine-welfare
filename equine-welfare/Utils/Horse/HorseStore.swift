import Foundation
import SwiftData

/// Owns all Horse *mutations* so views don't build `FetchDescriptor`s or call
/// `save()` in their button handlers. Reads stay in the views via `@Query`,
/// which is the idiomatic SwiftData reactivity path; this centralizes the
/// imperative create/update/delete work and throws so callers can surface
/// failures to the user rather than silently dropping them.
struct HorseStore {
    let modelContext: ModelContext

    enum StoreError: LocalizedError {
        case assessmentNotFound
        case horseNotFound

        var errorDescription: String? {
            switch self {
            case .assessmentNotFound: return "The assessment could not be found."
            case .horseNotFound: return "The horse could not be found."
            }
        }
    }

    func assessment(_ id: UUID) throws -> Assessment {
        let descriptor = FetchDescriptor<Assessment>(predicate: #Predicate { $0.id == id })
        guard let assessment = try modelContext.fetch(descriptor).first else {
            throw StoreError.assessmentNotFound
        }
        return assessment
    }

    func horse(_ id: UUID) throws -> Horse {
        let descriptor = FetchDescriptor<Horse>(predicate: #Predicate<Horse> { $0.uuid == id })
        guard let horse = try modelContext.fetch(descriptor).first else {
            throw StoreError.horseNotFound
        }
        return horse
    }

    /// Inserts a brand-new horse and links it to the given assessment.
    func add(_ horse: Horse, toAssessment assessmentId: UUID) throws {
        let assessment = try assessment(assessmentId)
        modelContext.insert(horse)
        horse.assessment = assessment
        assessment.horses.append(horse)
        try modelContext.save()
    }

    /// Applies the form-editable fields of a detached working copy onto the
    /// persisted horse. Fields the form doesn't touch (notes, directional
    /// photos, …) are left untouched.
    func update(from working: Horse) throws {
        let persisted = try horse(working.uuid)
        persisted.name = working.name
        persisted.age = working.age
        persisted.color = working.color
        persisted.sex = working.sex
        persisted.breed = working.breed
        persisted.otherBreed = working.otherBreed
        persisted.timeOnFarm = working.timeOnFarm
        persisted.bcsScore = working.bcsScore
        persisted.ageUnit = working.ageUnit
        persisted.timeUnit = working.timeUnit
        persisted.isHorse = working.isHorse
        persisted.photoData = working.photoData
        try modelContext.save()
    }

    /// Removes a horse from its assessment and deletes it.
    func delete(_ horse: Horse, fromAssessment assessmentId: UUID) throws {
        if let assessment = try? assessment(assessmentId),
           let index = assessment.horses.firstIndex(where: { $0.uuid == horse.uuid }) {
            assessment.horses.remove(at: index)
        }
        modelContext.delete(horse)
        try modelContext.save()
    }
}
