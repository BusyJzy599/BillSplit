import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSignUp = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "dollarsign.circle.fill")
                    .resizable().frame(width: 80, height: 80)
                    .foregroundStyle(.tint)

                Text("BillSplit")
                    .font(.largeTitle).fontWeight(.bold)

                Text("Split bills with friends")
                    .font(.subheadline).foregroundColor(.secondary)

                Spacer().frame(height: 16)

                // Email field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email").font(.caption).foregroundColor(.secondary)
                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .autocapitalization(.none).disableAutocorrection(true)
                        .padding(12).background(.ultraThinMaterial).cornerRadius(10)
                }

                // Name field (sign up only)
                if isSignUp {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name").font(.caption).foregroundColor(.secondary)
                        TextField("Your name", text: $name)
                            .padding(12).background(.ultraThinMaterial).cornerRadius(10)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Password
                VStack(alignment: .leading, spacing: 6) {
                    Text("Password").font(.caption).foregroundColor(.secondary)
                    SecureField("Min 6 characters", text: $password)
                        .padding(12).background(.ultraThinMaterial).cornerRadius(10)
                }

                // Error
                if let err = authVM.authError {
                    Text(err).font(.caption).foregroundColor(.red)
                }

                // Action button
                Button {
                    if isSignUp {
                        authVM.signUp(email: email, password: password, name: name.isEmpty ? email : name)
                    } else {
                        authVM.signIn(email: email, password: password)
                    }
                } label: {
                    if authVM.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(.tint).foregroundColor(.white).cornerRadius(12)
                .disabled(email.isEmpty || password.count < 6 || (isSignUp && name.isEmpty))

                // Toggle sign in/up
                Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                    withAnimation { isSignUp.toggle(); authVM.authError = nil }
                }
                .font(.subheadline).foregroundColor(.secondary)

                // Divider
                HStack {
                    Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                    Text("or").font(.caption).foregroundColor(.secondary)
                    Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                }

                // Apple Sign In
                Button { authService.startSignInWithAppleFlow() } label: {
                    HStack {
                        Image(systemName: "apple.logo").resizable().frame(width: 18, height: 22)
                        Text("Continue with Apple").fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(.black).cornerRadius(12)
                }

                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }
}
