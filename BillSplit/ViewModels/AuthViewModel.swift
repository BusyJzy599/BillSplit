import SwiftUI
import Supabase

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = true
    @Published var currentUserId: String?
    @Published var authError: String?
    @Published var emailConfirmationSent = false
    @Published var pendingEmail: String?

    init() {
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                await MainActor.run {
                    self.isLoggedIn = session != nil
                    self.currentUserId = session?.user.id.uuidString.lowercased()
                    self.isLoading = false
                    if session != nil {
                        self.emailConfirmationSent = false
                        self.pendingEmail = nil
                    }
                }
            }
        }
    }

    func signIn(email: String, password: String) {
        isLoading = true
        authError = nil
        emailConfirmationSent = false
        Task {
            do {
                _ = try await supabase.auth.signIn(email: email, password: password)
            } catch {
                await MainActor.run {
                    self.authError = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func signUp(email: String, password: String, name: String) {
        isLoading = true
        authError = nil
        Task {
            do {
                let response = try await supabase.auth.signUp(
                    email: email,
                    password: password,
                    data: ["full_name": .string(name)]
                )
                await MainActor.run {
                    self.isLoading = false
                    if response.session == nil {
                        self.emailConfirmationSent = true
                        self.pendingEmail = email
                    }
                }
            } catch {
                await MainActor.run {
                    self.authError = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func clearConfirmationState() {
        emailConfirmationSent = false
        pendingEmail = nil
        authError = nil
    }

    func signOut() {
        Task { try? await AuthService.shared.signOut() }
    }
}
