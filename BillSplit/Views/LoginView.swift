import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var loc = LocaleManager.shared
    @AppStorage("showTestAccounts") private var showTestAccounts = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isSignUp = false
    @FocusState private var focusedField: Field?

    enum Field { case email, name, password, confirmPassword }

    private func quickAuth(_ email: String, _ password: String, _ name: String) {
        authVM.isLoading = true
        authVM.authError = nil
        Task {
            do {
                _ = try await supabase.auth.signIn(email: email, password: password)
            } catch {
                do {
                    let resp = try await supabase.auth.signUp(email: email, password: password)
                    if resp.session == nil {
                        await MainActor.run {
                            authVM.authError = loc.emailConfirmRequired
                            authVM.isLoading = false
                        }
                        return
                    }
                } catch {
                    await MainActor.run {
                        authVM.authError = error.localizedDescription
                        authVM.isLoading = false
                    }
                }
            }
        }
    }

    private var passwordStrength: (level: Int, label: String, color: Color) {
        let hasUpper = password.contains(where: { $0.isUppercase })
        let hasLower = password.contains(where: { $0.isLowercase })
        let hasDigit = password.contains(where: { $0.isNumber })
        let len = password.count
        let score = (hasUpper ? 1 : 0) + (hasLower ? 1 : 0) + (hasDigit ? 1 : 0) + (len >= 8 ? 1 : 0) + (len >= 12 ? 1 : 0)
        switch score {
        case 0..<2: return (1, loc.locale == .zh ? "弱" : "Weak", .red)
        case 2..<3: return (2, loc.locale == .zh ? "一般" : "Fair", .orange)
        case 3..<4: return (3, loc.locale == .zh ? "好" : "Good", .yellow)
        default: return (4, loc.locale == .zh ? "强" : "Strong", .green)
        }
    }

    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = isSignUp ? (password.count >= 8 && passwordStrength.level >= 2 && password == confirmPassword) : (password.count >= 6)
        let nameValid = !isSignUp || !name.trimmingCharacters(in: .whitespaces).isEmpty
        return emailValid && passwordValid && nameValid && !authVM.isLoading
    }

    var body: some View {
        if authVM.emailConfirmationSent {
            confirmationView
        } else {
            loginFormView
        }
    }

    // MARK: - Email Confirmation

    var confirmationView: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle().fill(Color.blue.opacity(0.1)).frame(width: 100, height: 100)
                    Image(systemName: "envelope.open.fill")
                        .resizable().frame(width: 50, height: 35).foregroundStyle(.blue)
                }
                VStack(spacing: 8) {
                    Text(loc.checkEmailTitle)
                        .font(.title2).fontWeight(.bold)
                    Text(loc.checkEmailMsg(authVM.pendingEmail ?? ""))
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        authVM.clearConfirmationState()
                    }
                } label: {
                    Label(loc.backToLogin, systemImage: "arrow.left")
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered).tint(.blue).padding(.top, 12)

                Spacer()
            }
        }
    }

    // MARK: - Login / Sign Up Form

    var loginFormView: some View {
        ZStack {
            AppBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.blue, .teal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 72, height: 72)
                            Image(systemName: "dollarsign.circle.fill")
                                .resizable().frame(width: 40, height: 40)
                                .foregroundColor(.white)
                        }
                        .onTapGesture(count: 3) { showTestAccounts.toggle() }

                        VStack(spacing: 6) {
                            Text("BillSplit")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            Text(loc.appTagline)
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 24)

                    // Form card
                    VStack(spacing: 16) {
                        // Email
                        VStack(alignment: .leading, spacing: 6) {
                            Text(loc.email).font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                            HStack(spacing: 10) {
                                Image(systemName: "envelope.fill")
                                    .font(.subheadline).foregroundColor(.secondary).frame(width: 20)
                                TextField(loc.emailPlaceholder, text: $email)
                                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                                    .autocapitalization(.none).disableAutocorrection(true)
                                    .focused($focusedField, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = isSignUp ? .name : .password }
                            }
                            .padding(14).background(Color(.systemBackground)).cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focusedField == .email ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.5)
                            )
                        }

                        // Name (sign up only)
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(loc.nameField).font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                                HStack(spacing: 10) {
                                    Image(systemName: "person.fill")
                                        .font(.subheadline).foregroundColor(.secondary).frame(width: 20)
                                    TextField(loc.namePlaceholder, text: $name)
                                        .focused($focusedField, equals: .name)
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .password }
                                }
                                .padding(14).background(Color(.systemBackground)).cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == .name ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text(loc.password).font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                            HStack(spacing: 10) {
                                Image(systemName: "lock.fill")
                                    .font(.subheadline).foregroundColor(.secondary).frame(width: 20)
                                SecureField(loc.passwordPlaceholder, text: $password)
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(isSignUp ? .next : .go)
                                    .onSubmit { if isSignUp { focusedField = .confirmPassword } else { submit() } }
                            }
                            .padding(14).background(Color(.systemBackground)).cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focusedField == .password ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.5)
                            )
                            if isSignUp && !password.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(0..<4, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(i < passwordStrength.level ? passwordStrength.color : Color(.systemGray5))
                                            .frame(height: 3)
                                    }
                                    Text(passwordStrength.label).font(.caption2).foregroundColor(passwordStrength.color)
                                    if password.count < 8 {
                                        Text("· \(loc.minCharsHint)").font(.caption2).foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }

                        // Confirm password (sign up only)
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(loc.confirmPasswordLabel).font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                                HStack(spacing: 10) {
                                    Image(systemName: "lock.shield.fill")
                                        .font(.subheadline).foregroundColor(.secondary).frame(width: 20)
                                    SecureField(loc.passwordPlaceholder, text: $confirmPassword)
                                        .focused($focusedField, equals: .confirmPassword)
                                        .submitLabel(.go)
                                        .onSubmit { submit() }
                                }
                                .padding(14).background(Color(.systemBackground)).cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == .confirmPassword ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                )
                                if !confirmPassword.isEmpty && password != confirmPassword {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill").font(.caption2).foregroundColor(.red)
                                        Text(loc.passwordMismatch).font(.caption2).foregroundColor(.red)
                                    }
                                    .padding(.horizontal, 4)
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Error
                        if let err = authVM.authError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill").font(.caption2)
                                Text(err).font(.caption)
                            }
                            .foregroundColor(err.contains("sent") || err.contains("发送") || err.contains("check") || err.contains("查收") ? .blue : .red)
                            .padding(12)
                            .background((err.contains("sent") || err.contains("发送") || err.contains("check") || err.contains("查收") ? Color.blue : Color.red).opacity(0.08))
                            .cornerRadius(10)
                            .transition(.opacity.combined(with: .scale))
                        }

                        // Submit button
                        Button(action: submit) {
                            HStack(spacing: 8) {
                                if authVM.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: isSignUp ? "person.badge.plus" : "arrow.right.circle.fill")
                                        .font(.title3)
                                    Text(isSignUp ? loc.signUp : loc.signIn)
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(
                                isFormValid
                                    ? LinearGradient(colors: [.blue, .teal], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white).cornerRadius(14)
                        }
                        .disabled(!isFormValid)
                        .animation(.easeInOut(duration: 0.2), value: isFormValid)

                        // Toggle
                        Button(isSignUp ? loc.toggleSignIn : loc.toggleSignUp) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isSignUp.toggle()
                                authVM.authError = nil
                                focusedField = nil
                            }
                        }
                        .font(.subheadline).foregroundColor(.accentColor)
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                    )

                    // Test accounts
                    if showTestAccounts {
                        HStack(spacing: 12) {
                            Button { quickAuth("test1@billsplit.com", "test123", "Test User 1") } label: {
                                Label(loc.testAccount1, systemImage: "person.fill")
                                    .frame(maxWidth: .infinity).font(.subheadline)
                            }.buttonStyle(.bordered).tint(.blue)
                            Button { quickAuth("test2@billsplit.com", "test123", "Test User 2") } label: {
                                Label(loc.testAccount2, systemImage: "person.fill")
                                    .frame(maxWidth: .infinity).font(.subheadline)
                            }.buttonStyle(.bordered).tint(.green)
                        }
                        .padding(.top, 16)
                        .transition(.opacity)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onTapGesture { focusedField = nil }
    }

    private func submit() {
        guard isFormValid else { return }
        focusedField = nil
        if isSignUp {
            authVM.signUp(email: email.trimmingCharacters(in: .whitespaces),
                          password: password,
                          name: name.trimmingCharacters(in: .whitespaces).isEmpty ? email : name)
        } else {
            authVM.signIn(email: email.trimmingCharacters(in: .whitespaces),
                          password: password)
        }
    }
}
