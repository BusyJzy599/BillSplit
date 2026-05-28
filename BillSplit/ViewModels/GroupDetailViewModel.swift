import SwiftUI
import Supabase

class GroupDetailViewModel: ObservableObject {
    @Published var group: BillGroup
    @Published var bills: [Bill] = []
    @Published var settlements: [Settlement] = []
    @Published var userNames: [String: String] = [:]
    @Published var userAvatars: [String: String] = [:]
    @Published var debts: [DebtEntry] = []
    @Published var isReloading = false

    init(group: BillGroup) { self.group = group }

    /// Async reload — awaits completion before returning
    func reload() async {
        guard let groupId = group.id else { return }
        await MainActor.run { isReloading = true }
        do {
            var g = try await GroupService.shared.getGroup(id: groupId)
            g.memberIds = Array(Set(g.memberIds))
            let bills = try await BillService.shared.getBills(for: groupId)
            let settlements = try await SettlementService.shared.getSettlements(for: groupId)
            await MainActor.run {
                self.group = g
                self.bills = bills
                self.settlements = settlements
                recalcDebts()
                isReloading = false
            }
        } catch {
            await MainActor.run { isReloading = false }
            print("Reload failed: \(error)")
        }
    }

    func loadData() {
        guard let groupId = group.id else { return }
        Task {
            do {
                // Load group
                var g = try await GroupService.shared.getGroup(id: groupId)
                g.memberIds = Array(Set(g.memberIds))
                await MainActor.run { self.group = g }
                await fetchUserNames(ids: Set(g.memberIds))

                // Load bills
                let bills = try await BillService.shared.getBills(for: groupId)
                await MainActor.run { self.bills = bills }

                // Load settlements
                let settlements = try await SettlementService.shared.getSettlements(for: groupId)
                await MainActor.run { self.settlements = settlements }

                await MainActor.run { recalcDebts() }

                subscribeRealtime()
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

    // MARK: - Member balances

    func memberBalance(_ userId: String) -> Double {
        var net: Double = 0
        for bill in bills {
            let share = bill.amount / Double(max(bill.participantIds.count, 1))
            if bill.payerId == userId { net += bill.amount }
            if bill.participantIds.contains(userId) { net -= share }
        }
        for s in settlements where s.status == .paid {
            if s.fromUserId == userId { net += s.amount }
            if s.toUserId == userId { net -= s.amount }
        }
        return net
    }

    func balanceText(_ userId: String) -> String {
        let b = memberBalance(userId)
        if abs(b) < 0.01 { return "Settled" }
        return b > 0 ? "owed +\(CurrencySettings.shared.formatted(abs(b)))" : "owes \(CurrencySettings.shared.formatted(abs(b)))"
    }

    var totalSpent: Double { bills.reduce(0) { $0 + $1.amount } }

    // MARK: - Bill icons

    func billIcon(_ bill: Bill) -> String { bill.categoryEnum.icon }

    func billColor(_ bill: Bill) -> Color {
        switch bill.categoryEnum {
        case .dinner: return .orange
        case .coffee: return .brown
        case .transport: return .blue
        case .housing: return .indigo
        case .shopping: return .pink
        case .entertainment: return .purple
        case .travel: return .cyan
        case .medical: return .red
        case .education: return .yellow
        case .gift: return .mint
        case .utilities: return .teal
        case .other: return .green
        }
    }

    func subscribeRealtime() {
        guard let groupId = group.id else { return }
        RealtimeService.shared.subscribeBills(groupId: groupId) { [weak self] in
            self?.refreshData()
        }
        RealtimeService.shared.subscribeSettlements(groupId: groupId) { [weak self] in
            self?.refreshData()
        }
    }

    func unsubscribeRealtime() {
        guard let groupId = group.id else { return }
        RealtimeService.shared.unsubscribe(groupId: groupId)
    }

    private func refreshData() {
        guard let groupId = group.id else { return }
        Task {
            do {
                let bills = try await BillService.shared.getBills(for: groupId)
                let settlements = try await SettlementService.shared.getSettlements(for: groupId)
                await MainActor.run {
                    self.bills = bills
                    self.settlements = settlements
                    recalcDebts()
                }
            } catch {
                print("Refresh failed: \(error)")
            }
        }
    }
}
