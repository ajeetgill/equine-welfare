import SwiftUI

/// Toolbar account control. Cloud sync is the only feature that needs an
/// account, so this only appears once the user has signed in (via the sync
/// flow). It shows who's signed in and lets them sign out.
///
/// Sign-out only clears the locally stored PocketBase token. Local data is
/// untouched — signing out just revokes the ability to sync until someone
/// signs in again.
struct AccountMenu: View {
    // PocketBaseService is @Observable — reading isSignedIn here re-renders
    // on sign in / sign out, so the button appears and disappears.
    private var service = PocketBaseService.shared

    var body: some View {
        if service.isSignedIn {
            Menu {
                if let email = service.userEmail {
                    Text(email)
                }
                Button(role: .destructive) {
                    service.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "person.crop.circle")
                    .accessibilityLabel("Account")
            }
        }
    }
}
