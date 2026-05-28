import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text("用户 ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(authVM.currentUserId ?? "")
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
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
        }
    }
}
