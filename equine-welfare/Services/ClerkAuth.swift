import Foundation
import ClerkKit
import ConvexMobile

extension ConvexConfig {
    static var clerkPublishableKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "CLERK_PUBLISHABLE_KEY") as? String,
              !key.isEmpty else {
            fatalError("CLERK_PUBLISHABLE_KEY not found in Info.plist. Add it to your Secrets.xcconfig file.")
        }
        return key
    }
}

enum ClerkAuthError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        "Sign in required to sync. Please sign in and try again."
    }
}

/// Bridges Clerk sessions to Convex's `AuthProvider` protocol.
///
/// Sign-in UI is handled by Clerk's prebuilt `AuthView` in the view layer,
/// so `login()` here never presents anything — it just mints a Convex-template
/// JWT from the already-established Clerk session. `getToken` caches
/// internally, so repeated calls (e.g. a refresh between horses mid-sync)
/// only hit the network when the token is near expiry.
struct ClerkAuthProvider: AuthProvider {
    func login() async throws -> String {
        try await fetchToken()
    }

    func loginFromCache() async throws -> String {
        try await fetchToken()
    }

    func logout() async throws {
        try await Clerk.shared.auth.signOut()
    }

    func extractIdToken(from authResult: String) -> String {
        authResult
    }

    private func fetchToken() async throws -> String {
        guard let session = await Clerk.shared.session else {
            throw ClerkAuthError.notSignedIn
        }
        guard let jwt = try await session.getToken(.init(template: "convex")) else {
            throw ClerkAuthError.notSignedIn
        }
        return jwt
    }
}
