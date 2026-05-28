import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()
    private let db = Firestore.firestore()

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
        let doc = try await db.collection("users").document(userId).getDocument()
        if !doc.exists {
            let user = AppUser(displayName: displayName, email: email, createdAt: Timestamp())
            try db.collection("users").document(userId).setData(from: user)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
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

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        Auth.auth().signIn(with: firebaseCredential) { [weak self] result, error in
            guard let self = self, let user = result?.user else { return }
            let name = credential.fullName.map { "\($0.givenName ?? "") \($0.familyName ?? "")".trimmingCharacters(in: .whitespaces) } ?? "用户"
            Task {
                try? await self.saveUserIfNeeded(userId: user.uid, displayName: name, email: user.email ?? "")
                await MainActor.run { self.objectWillChange.send() }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple failed: \(error)")
    }
}
