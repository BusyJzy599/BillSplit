import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "dollarsign.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.tint)

                Text("账单共享")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("和朋友轻松分摊账单")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { _ in }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(12)
                .padding(.horizontal, 40)
                .onTapGesture {
                    authService.startSignInWithAppleFlow()
                }

                Spacer()
            }
        }
    }
}
