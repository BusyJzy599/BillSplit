import SwiftUI
import Supabase

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var loc = LocaleManager.shared
    @State private var displayName: String = ""
    @State private var avatarUrl: String?
    @State private var showEditProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                List {
                    Section {
                        HStack(spacing: 12) {
                            AvatarView(avatarUrl: avatarUrl, displayName: displayName, size: 60)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayName.isEmpty ? loc.user : displayName)
                                    .font(.headline)
                                Text(authVM.currentUserId ?? "")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button { showEditProfile = true } label: {
                                Image(systemName: "pencil.circle").font(.title2)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section(loc.displayCurrency) {
                        Picker(loc.displayCurrency, selection: Binding(
                            get: { CurrencySettings.shared.selectedCurrency },
                            set: { CurrencySettings.shared.selectedCurrency = $0; CurrencySettings.shared.objectWillChange.send() }
                        )) {
                            ForEach(Currency.allCases, id: \.rawValue) { c in
                                Text(c.name).tag(c.rawValue)
                            }
                        }
                    }

                    Section(loc.languageLabel) {
                        Picker(loc.languageLabel, selection: Binding(
                            get: { loc.appLocale },
                            set: { loc.appLocale = $0; loc.objectWillChange.send() }
                        )) {
                            Text("English").tag("en")
                            Text("中文").tag("zh")
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            authVM.signOut()
                        } label: {
                            Label(loc.signOut, systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(loc.navProfile)
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(displayName: displayName, avatarUrl: avatarUrl)
            }
            .onAppear { loadProfile() }
        }
    }

    private func loadProfile() {
        guard let userId = authVM.currentUserId else { return }
        Task {
            do {
                let users: [AppUser] = try await supabase.from("users").select().eq("id", value: userId).execute().value
                if let user = users.first {
                    await MainActor.run {
                        self.displayName = user.displayName
                        self.avatarUrl = user.avatarUrl
                    }
                }
            } catch { print("Load profile failed: \(error)") }
        }
    }
}
