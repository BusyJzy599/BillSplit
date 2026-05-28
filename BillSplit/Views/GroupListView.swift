import SwiftUI

struct GroupListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = GroupListViewModel()
    @StateObject private var loc = LocaleManager.shared
    @State private var showCreateSheet = false
    @State private var newGroupName = ""
    @State private var editingGroup: BillGroup?
    @State private var editGroupName = ""
    @State private var showEditSheet = false
    @State private var deletingGroup: BillGroup?
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if vm.groups.isEmpty && !authVM.isLoading {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "person.3.fill")
                            .resizable()
                            .frame(width: 60, height: 36)
                            .foregroundStyle(.secondary)
                        Text(loc.noGroups)
                            .font(.title3)
                            .fontWeight(.medium)
                        Text(loc.noGroupsHint)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button { showCreateSheet = true } label: {
                            Label(loc.newGroup, systemImage: "plus")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.groups) { group in
                                ZStack {
                                    NavigationLink(destination: GroupDetailView(group: group)) { EmptyView() }.opacity(0)
                                    GroupCard(group: group, userNames: vm.userNames, userAvatars: vm.userAvatars, currentUserId: authVM.currentUserId ?? "")
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deletingGroup = group
                                        showDeleteAlert = true
                                    } label: { Label(loc.delete, systemImage: "trash") }
                                    Button {
                                        editingGroup = group
                                        editGroupName = group.name
                                        showEditSheet = true
                                    } label: { Label(loc.edit, systemImage: "pencil") }
                                    .tint(.orange)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle(loc.navGroups)
            .toolbar {
                if !vm.groups.isEmpty {
                    Button { showCreateSheet = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                NavigationStack {
                    Form {
                        Section(loc.groupName) {
                            TextField(loc.groupNamePlaceholder, text: $newGroupName)
                        }
                    }
                    .navigationTitle(loc.newGroup)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(loc.cancel) { showCreateSheet = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(loc.create) {
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
            .sheet(isPresented: $showEditSheet) {
                NavigationStack {
                    Form {
                        Section(loc.groupName) {
                            TextField(loc.groupNamePlaceholder, text: $editGroupName)
                        }
                    }
                    .navigationTitle(loc.edit)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(loc.cancel) { showEditSheet = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(loc.save) {
                                if let g = editingGroup, let gid = g.id {
                                    Task {
                                        try? await supabase.from("groups").update(["name": editGroupName]).eq("id", value: gid).execute()
                                        vm.loadGroups(userId: authVM.currentUserId ?? "")
                                    }
                                    showEditSheet = false
                                }
                            }
                            .disabled(editGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .presentationDetents([.height(200)])
            }
            .alert(loc.deleteGroup, isPresented: $showDeleteAlert) {
                Button(loc.cancel, role: .cancel) {}
                Button(loc.delete, role: .destructive) {
                    if let g = deletingGroup, let gid = g.id {
                        Task { try? await GroupService.shared.deleteGroup(gid) }
                        vm.loadGroups(userId: authVM.currentUserId ?? "")
                    }
                }
            } message: {
                Text(loc.deleteBillMsg(deletingGroup?.name ?? ""))
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
    @StateObject private var loc = LocaleManager.shared

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(avatarUrl: userAvatars[group.creatorId], displayName: userNames[group.creatorId] ?? "", size: 48)

            VStack(alignment: .leading, spacing: 6) {
                Text(group.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Label("\(group.memberIds.count)", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("·").foregroundColor(.secondary)
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
