import SwiftUI
import Supabase

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUserId: String?

    init() {
        Task {
            for await (_, session) in supabase.auth.authStateChanges {
                await MainActor.run {
                    self.isLoggedIn = session != nil
                    self.currentUserId = session?.user.id.uuidString
                }
            }
        }
    }

    func signOut() {
        Task {
            try? await AuthService.shared.signOut()
        }
    }
}
