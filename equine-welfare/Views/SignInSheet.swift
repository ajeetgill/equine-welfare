import SwiftUI

/// Email + password sign-in against PocketBase. Replaces Clerk's AuthView.
/// Accounts are created by the administrator — there is no sign-up here.
struct SignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSigningIn = false

    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle("Sign In")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }

    private var formContent: some View {
        Form {
            SwiftUI.Section {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            if let errorMessage {
                SwiftUI.Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            SwiftUI.Section {
                Button {
                    signIn()
                } label: {
                    if isSigningIn {
                        ProgressView()
                    } else {
                        Text("Sign In")
                    }
                }
                .disabled(isSigningIn || email.isEmpty || password.isEmpty)
            } footer: {
                Text("Accounts are created by your administrator.")
            }
        }
    }

    private func signIn() {
        isSigningIn = true
        errorMessage = nil
        Task {
            do {
                try await PocketBaseService.shared.signIn(email: email, password: password)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSigningIn = false
        }
    }
}

#Preview {
    SignInSheet()
}
