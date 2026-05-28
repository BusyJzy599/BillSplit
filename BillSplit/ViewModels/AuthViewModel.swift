import SwiftUI
import Supabase

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = true
    @Published var currentUserId: String?

    init() {
        Task {
            for await (_, session) in supabase.auth.authStateChanges {
                await MainActor.run {
                    self.isLoggedIn = session != nil
                    self.currentUserId = session?.user.id.uuidString.lowercased()
                    self.isLoading = false
                }
            }
        }
        autoLoginForTesting()
    }

    private func autoLoginForTesting() {
        Task {
            let email = "test@billsplit.com"
            let password = "test123456"

            // Try sign in
            if let session = try? await supabase.auth.signIn(email: email, password: password) {
                await MainActor.run {
                    self.isLoggedIn = true
                    self.currentUserId = session.user.id.uuidString.lowercased()
                    self.isLoading = false
                }
                return
            }

            // Sign up if new user
            if let session = try? await supabase.auth.signUp(email: email, password: password) {
                await MainActor.run {
                    self.isLoggedIn = true
                    self.currentUserId = session.user.id.uuidString.lowercased()
                    self.isLoading = false
                }
                return
            }

            await MainActor.run { self.isLoading = false }
        }
    }

    func signOut() {
        Task {
            try? await AuthService.shared.signOut()
        }
    }
}
