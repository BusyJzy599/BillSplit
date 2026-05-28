import FirebaseFirestore
import SwiftUI

class GroupDetailViewModel: ObservableObject {
    @Published var group: BillGroup
    @Published var bills: [Bill] = []
    @Published var settlements: [Settlement] = []
    @Published var userNames: [String: String] = [:]
    @Published var debts: [DebtEntry] = []

    private var groupListener: ListenerRegistration?
    private var billsListener: ListenerRegistration?
    private var settlementsListener: ListenerRegistration?

    init(group: BillGroup) { self.group = group }

    func startListening() {
        guard let groupId = group.id else { return }

        groupListener = GroupService.shared.groupListener(groupId: groupId) { [weak self] snapshot, _ in
            guard let self = self, let data = snapshot?.data() else { return }
            var g = try! Firestore.Decoder().decode(BillGroup.self, from: data)
            g.id = groupId
            self.group = g
            self.fetchUserNames(ids: Set(g.memberIds))
        }

        billsListener = BillService.shared.billsListener(for: groupId) { [weak self] snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            self?.bills = docs.compactMap { try? $0.data(as: Bill.self) }
            self?.recalcDebts()
        }

        settlementsListener = SettlementService.shared.settlementsListener(for: groupId) { [weak self] snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            self?.settlements = docs.compactMap { try? $0.data(as: Settlement.self) }
            self?.recalcDebts()
        }
    }

    func stopListening() {
        groupListener?.remove()
        billsListener?.remove()
        settlementsListener?.remove()
    }

    private func recalcDebts() {
        debts = DebtCalculator.compute(bills: bills, settlements: settlements)
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

    func deleteGroup(userId: String) {
        guard let groupId = group.id else { return }
        Task {
            try? await GroupService.shared.deleteGroup(groupId)
        }
    }

    func leaveGroup(userId: String) {
        guard let groupId = group.id else { return }
        Task {
            try? await GroupService.shared.leaveGroup(groupId, userId: userId)
        }
    }

    func canLeave(userId: String) -> Bool {
        debts.contains { $0.fromUserId == userId || $0.toUserId == userId }
    }
}
