import ClerkKit
import SwiftUI

/// Toolbar account control. Cloud sync is the only feature that needs an
/// account, so this only appears once the user has signed in (via the sync
/// flow). It shows who's signed in and lets them sign out.
///
/// Sign-out clears the Clerk session for the whole device. This prototype does
/// not scope assessments per user, so local data is left untouched — signing
/// out only revokes the ability to sync until someone signs in again.
struct AccountMenu: View {
    @State private var isSigningOut = false

    var body: some View {
        // `Clerk` is @Observable, so reading `user` here re-renders on sign in
        // / sign out — the button appears and disappears automatically.
        if let user = Clerk.shared.user {
            Menu {
                if let email = user.primaryEmailAddress?.emailAddress {
                    Text(email)
                }
                Button(role: .destructive, action: signOut) {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .disabled(isSigningOut)
            } label: {
                Image(systemName: "person.crop.circle")
                    .accessibilityLabel("Account")
            }
        }
    }

    private func signOut() {
        isSigningOut = true
        Task {
            try? await Clerk.shared.auth.signOut()
            isSigningOut = false
        }
    }
}
