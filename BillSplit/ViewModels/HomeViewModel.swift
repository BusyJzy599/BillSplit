import SwiftUI
import Supabase

class HomeViewModel: ObservableObject {
    @Published var allBills: [Bill] = []
    @Published var allGroups: [BillGroup] = []
    @Published var isLoading = true

    func load(userId: String) {
        Task {
            do {
                let groups: [BillGroup] = try await supabase.from("groups")
                    .select().contains("member_ids", value: [userId])
                    .order("created_at", ascending: false).execute().value

                var bills: [Bill] = []
                for group in groups {
                    if let groupId = group.id {
                        let bs: [Bill] = try await supabase.from("bills")
                            .select().eq("group_id", value: groupId)
                            .order("created_at", ascending: false).execute().value
                        bills.append(contentsOf: bs)
                    }
                }

                await MainActor.run {
                    self.allGroups = groups
                    self.allBills = bills
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { self.isLoading = false }
                print("Home load failed: \(error)")
            }
        }
    }

    // MARK: - Summary stats

    var totalPaid: Double {
        allBills.reduce(0) { $0 + $1.amount }
    }

    var totalBills: Int {
        allBills.count
    }

    var totalGroups: Int {
        allGroups.count
    }

    // MARK: - Daily spending for heatmap (last 84 days ~ 12 weeks)

    var dailySpending: [(date: Date, amount: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -83, to: today)!

        var map: [Date: Double] = [:]
        for bill in allBills {
            let day = calendar.startOfDay(for: bill.createdAt)
            map[day, default: 0] += bill.amount
        }

        var result: [(Date, Double)] = []
        var d = start
        while d <= today {
            result.append((d, map[d] ?? 0))
            d = calendar.date(byAdding: .day, value: 1, to: d)!
        }
        return result
    }

    // MARK: - Category breakdown for pie chart (by description keyword)

    var categoryBreakdown: [(name: String, amount: Double)] {
        var categories: [String: Double] = [:]

        for bill in allBills {
            let cat = categorize(bill.description)
            categories[cat, default: 0] += bill.amount
        }

        return categories
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    private func categorize(_ desc: String) -> String {
        let lower = desc.lowercased()
        if lower.contains("餐") || lower.contains("饭") || lower.contains("吃") || lower.contains("food") || lower.contains("dinner") || lower.contains("lunch") { return "餐饮" }
        if lower.contains("交通") || lower.contains("车") || lower.contains("打车") || lower.contains("taxi") || lower.contains("bus") { return "交通" }
        if lower.contains("住") || lower.contains("房") || lower.contains("租") || lower.contains("rent") || lower.contains("hotel") { return "住宿" }
        if lower.contains("购物") || lower.contains("买") || lower.contains("shop") || lower.contains("buy") { return "购物" }
        if lower.contains("娱") || lower.contains("玩") || lower.contains("电影") || lower.contains("game") || lower.contains("movie") { return "娱乐" }
        return "其他"
    }

    // MARK: - Color for heatmap cell

    func heatmapColor(for amount: Double) -> Color {
        let maxAmount = dailySpending.map(\.amount).max() ?? 1
        let ratio = maxAmount > 0 ? amount / maxAmount : 0
        if ratio <= 0 { return Color(.systemGray6) }
        if ratio < 0.25 { return .green.opacity(0.3) }
        if ratio < 0.5 { return .green.opacity(0.6) }
        if ratio < 0.75 { return .green.opacity(0.8) }
        return .green
    }
}
