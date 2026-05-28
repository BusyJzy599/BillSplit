import FirebaseFirestore
import SwiftUI

class GroupListViewModel: ObservableObject {
    @Published var groups: [BillGroup] = []
    @Published var userNames: [String: String] = [:]

    private var listener: ListenerRegistration?

    func startListening(userId: String) {
        listener = GroupService.shared.groupsListener(for: userId) { [weak self] snapshot, error in
            guard let docs = snapshot?.documents else { return }
            let groups = docs.compactMap { try? $0.data(as: BillGroup.self) }
            self?.groups = groups

            let allMemberIds = Set(groups.flatMap { $0.memberIds })
            self?.fetchUserNames(ids: allMemberIds)
        }
    }

    func stopListening() {
        listener?.remove()
    }

    private func fetchUserNames(ids: Set<String>) {
        for id in ids where userNames[id] == nil {
            Firestore.firestore().collection("users").document(id).getDocument { [weak self] doc, _ in
                if let user = try? doc?.data(as: AppUser.self) {
                    self?.userNames[id] = user.displayName
                }
            }
        }
    }

    func createGroup(name: String, userId: String) {
        Task {
            do {
                _ = try await GroupService.shared.createGroup(name: name, creatorId: userId)
            } catch {
                print("Create group failed: \(error)")
            }
        }
    }
}
