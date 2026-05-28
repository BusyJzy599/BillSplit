import SwiftUI
import Supabase

class GroupDetailViewModel: ObservableObject {
    @Published var group: BillGroup
    @Published var bills: [Bill] = []
    @Published var settlements: [Settlement] = []
    @Published var userNames: [String: String] = [:]
    @Published var debts: [DebtEntry] = []

    init(group: BillGroup) { self.group = group }

    func loadData() {
        guard let groupId = group.id else { return }
        Task {
            do {
                // Load group
                let g = try await GroupService.shared.getGroup(id: groupId)
                await MainActor.run { self.group = g }
                await fetchUserNames(ids: Set(g.memberIds))

                // Load bills
                let bills = try await BillService.shared.getBills(for: groupId)
                await MainActor.run { self.bills = bills }

                // Load settlements
                let settlements = try await SettlementService.shared.getSettlements(for: groupId)
                await MainActor.run { self.settlements = settlements }

                await MainActor.run { recalcDebts() }
            } catch {
                print("Load data failed: \(error)")
            }
        }
    }

    private func recalcDebts() {
        debts = DebtCalculator.compute(bills: bills, settlements: settlements)
    }

    private func fetchUserNames(ids: Set<String>) async {
        for id in ids where userNames[id] == nil {
            do {
                let users: [AppUser] = try await supabase.from("users").select().eq("id", value: id).execute().value
                if let user = users.first {
                    await MainActor.run { self.userNames[id] = user.displayName }
                }
            } catch {
                print("Fetch user failed: \(error)")
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
