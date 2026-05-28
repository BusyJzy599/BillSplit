import SwiftUI
import Supabase

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = true
    @Published var currentUserId: String?
    @Published var authError: String?

    init() {
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                await MainActor.run {
                    self.isLoggedIn = session != nil
                    self.currentUserId = session?.user.id.uuidString.lowercased()
                    self.isLoading = false
                }
            }
        }
    }

    func signIn(email: String, password: String) {
        isLoading = true
        authError = nil
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
                let session = try await supabase.auth.signUp(email: email, password: password)
                // Update display name in public.users
                let uid = session.user.id.uuidString.lowercased()
                try? await supabase.from("users")
                    .update(["display_name": name])
                    .eq("id", value: uid)
                    .execute()
            } catch {
                await MainActor.run {
                    self.authError = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func signOut() {
        Task { try? await AuthService.shared.signOut() }
    }
}
