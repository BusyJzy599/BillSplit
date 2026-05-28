import FirebaseAuth
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUserId: String?

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isLoggedIn = user != nil
            self?.currentUserId = user?.uid
        }
    }

    deinit {
        if let handle = handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    func signOut() {
        try? AuthService.shared.signOut()
    }
}
