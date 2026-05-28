import SwiftUI
import Supabase

class GroupListViewModel: ObservableObject {
    @Published var groups: [BillGroup] = []
    @Published var userNames: [String: String] = [:]
    @Published var userAvatars: [String: String] = [:]

    func loadGroups(userId: String) {
        Task {
            do {
                let groups = try await GroupService.shared.getGroups(for: userId)
                await MainActor.run { self.groups = groups }
                let allMemberIds = Set(groups.flatMap { $0.memberIds })
                await fetchUserNames(ids: allMemberIds)
            } catch {
                print("Load groups failed: \(error)")
            }
        }
    }

    func refreshGroups(userId: String) async {
        do {
            let groups = try await GroupService.shared.getGroups(for: userId)
            await MainActor.run { self.groups = groups }
            let allMemberIds = Set(groups.flatMap { $0.memberIds })
            await fetchUserNames(ids: allMemberIds)
        } catch {
            print("Refresh groups failed: \(error)")
        }
    }

    private func fetchUserNames(ids: Set<String>) async {
        for id in ids where userNames[id] == nil {
            do {
                let users: [AppUser] = try await supabase.from("users").select().eq("id", value: id).execute().value
                if let user = users.first {
                    await MainActor.run {
                        self.userNames[id] = user.displayName
                        self.userAvatars[id] = user.avatarUrl
                    }
                }
            } catch {
                print("Fetch user failed: \(error)")
            }
        }
    }

    func createGroup(name: String, userId: String) {
        Task {
            do {
                _ = try await GroupService.shared.createGroup(name: name, creatorId: userId)
                loadGroups(userId: userId)
            } catch {
                print("Create group failed: \(error)")
            }
        }
    }
}
