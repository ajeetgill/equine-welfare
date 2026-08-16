import Foundation

/// Sync-button state for one assessment row, extracted from
/// PreviousAssessmentRow. Owns the upload lifecycle (progress, success and
/// error alerts) so the row view only renders it. MainActor-isolated so
/// progress callbacks from URLSession land on the UI thread.
@MainActor
@Observable
final class AssessmentSyncViewModel {
    private(set) var isUploading = false
    var uploadProgress: Double = 0.0
    var uploadError: String?
    var showUploadAlert = false
    var showUploadSuccess = false
    var uploadSuccessMessage: String?
    var isUploadingMedia = false

    func sync(_ assessment: Assessment) async {
        isUploading = true
        uploadProgress = 0.1

        do {
            try await PocketBaseService.shared.syncAssessment(assessment) { [weak self] message, progress in
                Task { @MainActor in
                    self?.uploadProgress = progress
                    self?.isUploadingMedia = message.contains("media")
                }
            }

            uploadSuccessMessage = "Assessment synced successfully!"
            showUploadSuccess = true
            uploadError = nil
            isUploadingMedia = false
            uploadProgress = 1.0
        } catch {
            uploadError = Self.errorMessage(for: error)
            showUploadAlert = true
        }

        isUploading = false
        uploadProgress = 0.0
    }

    /// User-facing alert copy for each failure class.
    nonisolated static func errorMessage(for error: Error) -> String {
        if let error = error as? PocketBaseError {
            // PocketBase errors are structured — no string matching needed.
            return error.localizedDescription
        }
        if let error = error as? URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotConnectToHost, .cannotFindHost:
                return "Could not reach the sync server. Check that you're on the same network and PocketBase is running."
            default:
                return "Sync failed. Please try again later."
            }
        }
        return "Sync failed. Please try again later."
    }
}
