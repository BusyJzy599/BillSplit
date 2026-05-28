import SwiftUI

struct GroupListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = GroupListViewModel()
    @State private var showCreateSheet = false
    @State private var newGroupName = ""

    var body: some View {
        NavigationStack {
            Group {
                if vm.groups.isEmpty && !authVM.isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .resizable()
                            .frame(width: 60, height: 36)
                            .foregroundStyle(.secondary)
                        Text("还没有账单组")
                            .font(.title3)
                            .fontWeight(.medium)
                        Text("创建一个账单组，邀请朋友一起分摊")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button {
                            showCreateSheet = true
                        } label: {
                            Label("新建账单组", systemImage: "plus")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.groups) { group in
                                NavigationLink(destination: GroupDetailView(group: group)) {
                                    GroupCard(group: group, userNames: vm.userNames, userAvatars: vm.userAvatars, currentUserId: authVM.currentUserId ?? "")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("我的账单组")
            .toolbar {
                if !vm.groups.isEmpty {
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                NavigationStack {
                    Form {
                        Section("账单组名称") {
                            TextField("例如: 旅行聚餐", text: $newGroupName)
                        }
                    }
                    .navigationTitle("新建账单组")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("取消") { showCreateSheet = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("创建") {
                                vm.createGroup(name: newGroupName, userId: authVM.currentUserId ?? "")
                                newGroupName = ""
                                showCreateSheet = false
                            }
                            .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .presentationDetents([.height(220)])
            }
        }
        .onAppear {
            if let uid = authVM.currentUserId { vm.loadGroups(userId: uid) }
        }
    }
}

struct GroupCard: View {
    let group: BillGroup
    let userNames: [String: String]
    let userAvatars: [String: String]
    let currentUserId: String

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(avatarUrl: userAvatars[group.creatorId], displayName: userNames[group.creatorId] ?? "", size: 48)

            VStack(alignment: .leading, spacing: 6) {
                Text(group.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Label("\(group.memberIds.count)人", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(.secondary)

                    Label(group.inviteCode, systemImage: "key")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(group.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}
