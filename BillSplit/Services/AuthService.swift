import AuthenticationServices
import CryptoKit
import Supabase

class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    private var currentNonce: String?

    func startSignInWithAppleFlow() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    func saveUserIfNeeded(userId: String, displayName: String, email: String) async throws {
        let existing: [AppUser] = try await supabase.from("users").select().eq("id", value: userId).execute().value
        if existing.isEmpty {
            let user = AppUser(id: userId, displayName: displayName, email: email, createdAt: Date())
            try await supabase.from("users").insert(user).execute()
        }
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in charset[Int.random(in: 0..<charset.count)] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let token = credential.identityToken,
              let tokenString = String(data: token, encoding: .utf8) else { return }

        Task {
            do {
                try await supabase.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: tokenString, nonce: nonce)
                )
                let user = try await supabase.auth.session.user
                let name = credential.fullName.map { "\($0.givenName ?? "") \($0.familyName ?? "")".trimmingCharacters(in: .whitespaces) } ?? "用户"
                try? await saveUserIfNeeded(userId: user.id.uuidString, displayName: name, email: user.email ?? "")
                await MainActor.run { self.objectWillChange.send() }
            } catch {
                print("Sign in failed: \(error)")
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple failed: \(error)")
    }
}
