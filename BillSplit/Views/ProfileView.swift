import SwiftUI
import Supabase

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var displayName: String = ""
    @State private var avatarUrl: String?
    @State private var showEditProfile = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        AvatarView(avatarUrl: avatarUrl, displayName: displayName, size: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName.isEmpty ? "用户" : displayName)
                                .font(.headline)
                            Text(authVM.currentUserId ?? "")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            showEditProfile = true
                        } label: {
                            Image(systemName: "pencil.circle")
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button(role: .destructive) {
                        authVM.signOut()
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("个人中心")
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(displayName: displayName, avatarUrl: avatarUrl)
            }
            .onAppear {
                loadProfile()
            }
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
            } catch {
                print("Load profile failed: \(error)")
            }
        }
    }
}
