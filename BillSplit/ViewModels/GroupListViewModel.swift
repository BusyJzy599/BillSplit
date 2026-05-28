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
        let missingIds = ids.filter { userNames[$0] == nil }
        guard !missingIds.isEmpty else { return }
        do {
            let users: [AppUser] = try await supabase.from("users")
                .select().in("id", values: Array(missingIds)).execute().value
            await MainActor.run {
                for user in users {
                    self.userNames[user.id] = user.displayName
                    self.userAvatars[user.id] = user.avatarUrl
                }
            }
        } catch {
            print("Fetch users failed: \(error)")
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
