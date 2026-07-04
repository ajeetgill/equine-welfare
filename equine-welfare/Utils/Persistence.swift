import Foundation
import SwiftData
import os

extension Logger {
    /// App-wide logger for persistence failures.
    static let persistence = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "equine-welfare",
        category: "persistence"
    )
}

extension ModelContext {
    /// Saves pending changes, logging any failure instead of silently
    /// swallowing it with `try?`.
    ///
    /// Use this for incidental saves (autosaving a note, a photo) where a
    /// failure should be recorded but needn't interrupt the user. For
    /// user-initiated create/edit/delete, call `save()` inside a do/catch that
    /// surfaces the error (see `HorseStore` + the alerts in the horse flow).
    @discardableResult
    func saveOrLog(_ operation: String) -> Bool {
        do {
            try save()
            return true
        } catch {
            Logger.persistence.error(
                "Failed to save (\(operation, privacy: .public)): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }
}
