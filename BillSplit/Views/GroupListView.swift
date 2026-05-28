import SwiftUI

struct GroupListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = GroupListViewModel()
    @State private var showCreateSheet = false
    @State private var newGroupName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.groups) { group in
                        NavigationLink(destination: GroupDetailView(group: group)) {
                            GroupCard(group: group, userNames: vm.userNames, currentUserId: authVM.currentUserId ?? "")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("我的账单组")
            .toolbar {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                NavigationStack {
                    Form {
                        TextField("账单组名称", text: $newGroupName)
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
                .presentationDetents([.height(200)])
            }
            .onAppear {
                if let uid = authVM.currentUserId { vm.startListening(userId: uid) }
            }
            .onDisappear { vm.stopListening() }
        }
    }
}

struct GroupCard: View {
    let group: BillGroup
    let userNames: [String: String]
    let currentUserId: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(group.name)
                        .font(.headline)
                    Spacer()
                    Text("\(group.memberIds.count)人")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("邀请码")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(group.inviteCode)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    Spacer()
                    Text(group.createdAt.dateValue(), style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
