import SwiftUI
import Supabase

class GroupDetailViewModel: ObservableObject {
    @Published var group: BillGroup
    @Published var bills: [Bill] = []
    @Published var settlements: [Settlement] = []
    @Published var userNames: [String: String] = [:]
    @Published var userAvatars: [String: String] = [:]
    @Published var debts: [DebtEntry] = []

    init(group: BillGroup) { self.group = group }

    /// Async reload — awaits completion before returning
    func reload() async {
        guard let groupId = group.id else { return }
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
            }
        } catch { print("Reload failed: \(error)") }
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

    func billIcon(_ bill: Bill) -> String {
        let d = bill.description.lowercased()
        if d.contains("dinner") || d.contains("lunch") || d.contains("food") || d.contains("餐") || d.contains("饭") || d.contains("吃") { return "🍽️" }
        if d.contains("taxi") || d.contains("bus") || d.contains("uber") || d.contains("交通") || d.contains("车") { return "🚗" }
        if d.contains("drink") || d.contains("beer") || d.contains("coffee") || d.contains("酒") || d.contains("饮料") { return "🍺" }
        if d.contains("hotel") || d.contains("rent") || d.contains("住") || d.contains("房") { return "🏠" }
        if d.contains("shop") || d.contains("buy") || d.contains("购物") || d.contains("买") { return "🛍️" }
        if d.contains("movie") || d.contains("game") || d.contains("娱") || d.contains("玩") { return "🎮" }
        if d.contains("flight") || d.contains("train") || d.contains("机票") || d.contains("火车") { return "✈️" }
        return "💰"
    }

    func billColor(_ bill: Bill) -> Color {
        let icons: [String: Color] = ["🍽️": .orange, "🚗": .blue, "🍺": .yellow, "🏠": .brown, "🛍️": .pink, "🎮": .purple, "✈️": .cyan, "💰": .green]
        return icons[billIcon(bill)] ?? .gray
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
