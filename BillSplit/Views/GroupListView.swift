import SwiftUI

struct GroupListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = GroupListViewModel()
    @StateObject private var loc = LocaleManager.shared
    @State private var showCreateSheet = false
    @State private var newGroupName = ""
    @State private var editingGroup: BillGroup?
    @State private var editGroupName = ""
    @State private var editGroupIcon = ""
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
                        Image(systemName: "person.3.fill").resizable().frame(width: 60, height: 36).foregroundStyle(.secondary)
                        Text(loc.noGroups).font(.title3).fontWeight(.medium)
                        Text(loc.noGroupsHint).font(.subheadline).foregroundColor(.secondary)
                        Button { showCreateSheet = true } label: {
                            Label(loc.newGroup, systemImage: "plus").fontWeight(.semibold)
                        }.buttonStyle(.borderedProminent)
                        Spacer()
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
                } else {
                    List {
                        ForEach(vm.groups) { group in
                            NavigationLink(destination: GroupDetailView(group: group)) {
                                groupRow(group)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deletingGroup = group
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showDeleteAlert = true }
                                } label: { Label(loc.delete, systemImage: "trash") }
                                Button {
                                    editingGroup = group; editGroupName = group.name; editGroupIcon = group.icon
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showEditSheet = true }
                                } label: { Label(loc.edit, systemImage: "pencil") }.tint(.orange)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(loc.navGroups)
            .toolbar {
                if !vm.groups.isEmpty { Button { showCreateSheet = true } label: { Image(systemName: "plus") } }
            }
            .sheet(isPresented: $showCreateSheet) {
                NavigationStack {
                    Form { Section(loc.groupName) { TextField(loc.groupNamePlaceholder, text: $newGroupName) } }
                    .navigationTitle(loc.newGroup).navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(loc.cancel) { showCreateSheet = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(loc.create) {
                                vm.createGroup(name: newGroupName, userId: authVM.currentUserId ?? "")
                                newGroupName = ""; showCreateSheet = false
                            }.disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }.presentationDetents([.height(220)])
            }
            .sheet(isPresented: $showEditSheet) {
                editSheet
            }
            .alert(loc.deleteGroup, isPresented: $showDeleteAlert) {
                Button(loc.cancel, role: .cancel) {}
                Button(loc.delete, role: .destructive) { confirmDelete() }
            } message: { Text(loc.deleteBillMsg(deletingGroup?.name ?? "")) }
        }
        .onAppear { if let uid = authVM.currentUserId { vm.loadGroups(userId: uid) } }
    }

    // MARK: - Group Row

    private func groupRow(_ group: BillGroup) -> some View {
        HStack(spacing: 12) {
            Text(group.icon).font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name).font(.headline).fontWeight(.semibold)
                HStack(spacing: 6) {
                    Label("\(group.memberIds.count)", systemImage: "person.2").font(.caption).foregroundColor(.secondary)
                    Text(group.inviteCode).font(.system(.caption, design: .monospaced)).foregroundColor(.accentColor)
                }
            }
            Spacer()
            Text(group.createdAt, style: .date).font(.caption2).foregroundColor(.secondary)
        }.padding(.vertical, 4)
    }

    // MARK: - Edit Sheet

    private var editSheet: some View {
        let icons = ["👥","🏠","✈️","🍽️","🎉","🎓","💼","🏖️","🎮","🏃","☕","🎵","💡","🐶","🌍","📚","🎬","⚽"]
        return NavigationStack {
            Form {
                Section(loc.groupName) { TextField(loc.groupNamePlaceholder, text: $editGroupName) }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(icons, id: \.self) { icon in
                            Text(icon).font(.title2).frame(width: 40, height: 40)
                                .background(editGroupIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(8).onTapGesture { editGroupIcon = icon }
                        }
                    }
                }
            }
            .navigationTitle(loc.edit).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(loc.cancel) { showEditSheet = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.save) { confirmEdit() }.disabled(editGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }.presentationDetents([.height(350)])
    }

    // MARK: - Actions (properly awaited)

    private func confirmEdit() {
        guard let g = editingGroup, let gid = g.id else { return }
        Task {
            do {
                try await supabase.from("groups").update(["name": editGroupName, "icon": editGroupIcon]).eq("id", value: gid).execute()
                await MainActor.run { showEditSheet = false }
                vm.loadGroups(userId: authVM.currentUserId ?? "")
            } catch { print("Edit group failed: \(error)") }
        }
    }

    private func confirmDelete() {
        guard let g = deletingGroup, let gid = g.id else { return }
        Task {
            do {
                try await GroupService.shared.deleteGroup(gid)
                await MainActor.run { vm.loadGroups(userId: authVM.currentUserId ?? "") }
            } catch { print("Delete group failed: \(error)") }
        }
    }
}
