import Foundation
import Testing
@testable import Horse_C_O_P

/// The sync alert copy the user sees for each failure class, extracted from
/// the row view into AssessmentSyncViewModel.
struct SyncErrorMessageTests {
    @Test func pocketBaseErrorsUseTheirOwnDescription() {
        #expect(AssessmentSyncViewModel.errorMessage(for: PocketBaseError.notSignedIn)
                == "Sign in required to sync. Please sign in and try again.")
        #expect(AssessmentSyncViewModel.errorMessage(for: PocketBaseError.server("Sync failed inside transaction."))
                == "Sync failed inside transaction.")
        #expect(AssessmentSyncViewModel.errorMessage(for: PocketBaseError.uploadFailed)
                == "Failed to upload media file")
    }

    @Test func connectivityURLErrorsExplainTheLANSetup() {
        for code in [URLError.notConnectedToInternet, .networkConnectionLost, .timedOut,
                     .cannotConnectToHost, .cannotFindHost] {
            #expect(AssessmentSyncViewModel.errorMessage(for: URLError(code))
                    == "Could not reach the sync server. Check that you're on the same network and PocketBase is running.")
        }
    }

    @Test func otherErrorsFallBackToGenericMessage() {
        #expect(AssessmentSyncViewModel.errorMessage(for: URLError(.badServerResponse))
                == "Sync failed. Please try again later.")
        struct SomeError: Error {}
        #expect(AssessmentSyncViewModel.errorMessage(for: SomeError())
                == "Sync failed. Please try again later.")
    }
}
