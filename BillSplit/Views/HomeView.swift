import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = HomeViewModel()
    @StateObject private var loc = LocaleManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundLight().ignoresSafeArea()

                if vm.isLoading {
                    ProgressView(loc.loading)
                } else if vm.allBills.isEmpty && vm.allGroups.isEmpty {
                    VStack(spacing: 12) {
                        Text(["💰", "🧾", "📊", "🤝", "✨"].randomElement() ?? "💰").font(.system(size: 50))
                        Text(loc.noDataYet).font(.title3).fontWeight(.medium)
                        Text(loc.noDataHint).font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Greeting
                            greetingSection

                            // Summary cards
                            summarySection

                            // Heatmap
                            heatmapSection

                            // Pie + list side by side on wider screens, stacked otherwise
                            if !vm.categoryBreakdown.isEmpty {
                                VStack(spacing: 12) {
                                    pieSection
                                    categoryListSection
                                }
                            }

                            Spacer().frame(height: 32)
                        }
                        .padding(16)
                    }
                    .refreshable { if let uid = authVM.currentUserId { await vm.refresh(userId: uid) } }
                }
            }
            .navigationTitle(loc.navHome)
            .onAppear { if let uid = authVM.currentUserId { vm.load(userId: uid) } }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("refreshGroups"))) { _ in
                if let uid = authVM.currentUserId { vm.load(userId: uid) }
            }
        }
    }

    // MARK: - Greeting

    private var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<9: return "🌅"
        case 9..<12: return "☀️"
        case 12..<14: return "🍜"
        case 14..<17: return "🌤️"
        case 17..<20: return "🌆"
        case 20..<23: return "🌙"
        default: return "🌃"
        }
    }

    private var spendingMood: String {
        let total = vm.totalPaid
        if total == 0 { return "" }
        let recentBills = vm.allBills.prefix(7)
        let avg = recentBills.map(\.amount).reduce(0, +) / Double(max(recentBills.count, 1))
        if avg < 50 { return loc.locale == .zh ? "精打细算，生活高手！💰" : "Thrifty living, nice work! 💰" }
        if avg < 200 { return loc.locale == .zh ? "适度消费，刚刚好～ 👌" : "Balanced spending, just right～ 👌" }
        return loc.locale == .zh ? "最近花销不小哦，注意记账！📝" : "Spending big lately, keep tracking! 📝"
    }

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(greetingEmoji).font(.title)
                Text(vm.totalBills > 0
                     ? (loc.locale == .zh ? "今天也辛苦了！" : "Another day, another adventure!")
                     : (loc.locale == .zh ? "欢迎来到 BillSplit！" : "Welcome to BillSplit!"))
                    .font(.title3).fontWeight(.bold)
            }
            if !spendingMood.isEmpty {
                Text(spendingMood).font(.subheadline).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Summary

    private var summarySection: some View {
        HStack(spacing: 10) {
            statCard(value: CurrencySettings.shared.formatted(vm.totalPaid), label: loc.totalSpent, emoji: "💸")
            statCard(value: "\(vm.totalBills)", label: loc.billCount, emoji: "📋")
            statCard(value: "\(vm.totalGroups)", label: loc.groupCount, emoji: "👥")
        }
    }

    private func statCard(value: String, label: String, emoji: String = "") -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 20)).frame(height: 24)
            Text(value).font(.system(.headline, design: .rounded)).fontWeight(.bold)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(label).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.04), radius: 4))
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(loc.spendingHeatmap, systemImage: "calendar")
                .font(.subheadline).fontWeight(.medium)
            heatmapGrid
            // Legend
            HStack(spacing: 6) {
                Text(loc.less).font(.caption2).foregroundColor(.secondary)
                heatmapLegendBlock(opacity: 0)
                heatmapLegendBlock(opacity: 0.25)
                heatmapLegendBlock(opacity: 0.5)
                heatmapLegendBlock(opacity: 0.75)
                heatmapLegendBlock(opacity: 1.0)
                Text(loc.more).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.04), radius: 4))
    }

    private var heatmapGrid: some View {
        let data = vm.dailySpending
        let cols = 7
        let maxAmount = data.map(\.amount).max() ?? 1
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: cols), spacing: 2) {
            ForEach(0..<data.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(cellColor(data[i].amount, max: maxAmount))
                    .frame(height: 14)
            }
        }
    }

    private func cellColor(_ amount: Double, max maxAmount: Double) -> Color {
        let ratio = maxAmount > 0 ? amount / maxAmount : 0
        if ratio <= 0 { return Color(.systemGray5) }
        switch ratio {
        case 0..<0.25: return .green.opacity(0.25)
        case 0.25..<0.5: return .green.opacity(0.5)
        case 0.5..<0.75: return .green.opacity(0.75)
        default: return .green
        }
    }

    private func heatmapLegendBlock(opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(opacity > 0 ? .green.opacity(opacity) : Color(.systemGray5))
            .frame(width: 12, height: 12)
    }

    // MARK: - Pie

    private var pieSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(loc.categoryBreakdown, systemImage: "chart.pie.fill")
                .font(.subheadline).fontWeight(.medium)
            GeometryReader { geo in
                let pieSize = min(geo.size.width * 0.35, 140)
                HStack(spacing: 16) {
                    PieChartView(data: vm.categoryBreakdown).frame(width: pieSize, height: pieSize)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(vm.categoryBreakdown.prefix(4), id: \.name) { item in
                            HStack(spacing: 6) {
                                Circle().fill(pieColor(item.name)).frame(width: 6, height: 6)
                                Text(item.name).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                Text(CurrencySettings.shared.formatted(item.amount)).font(.caption).fontWeight(.medium).lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: min(UIScreen.main.bounds.width * 0.35, 140))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.04), radius: 4))
    }

    // MARK: - Category List

    private var categoryListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(loc.categoryDetail, systemImage: "list.bullet.rectangle")
                .font(.subheadline).fontWeight(.medium)
            ForEach(vm.categoryBreakdown, id: \.name) { item in
                HStack {
                    Circle().fill(pieColor(item.name)).frame(width: 8, height: 8)
                    Text(item.name).font(.subheadline)
                    Spacer()
                    Text(CurrencySettings.shared.formatted(item.amount)).font(.subheadline).fontWeight(.semibold)
                    Text(String(format: "%.0f%%", vm.totalPaid > 0 ? item.amount / vm.totalPaid * 100 : 0))
                        .font(.caption).foregroundColor(.secondary).frame(width: 40, alignment: .trailing)
                }
                if item.name != vm.categoryBreakdown.last?.name { Divider() }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.04), radius: 4))
    }

    private func pieColor(_ name: String) -> Color {
        let colors: [Color] = [.orange, .blue, .green, .pink, .purple, .yellow, .teal, .red]
        let idx = vm.categoryBreakdown.firstIndex(where: { $0.name == name }) ?? 0
        return colors[idx % colors.count]
    }
}

// MARK: - Pie Chart

struct PieChartView: View {
    let data: [(name: String, amount: Double)]
    var body: some View {
        let total = data.map(\.amount).reduce(0, +)
        let angles = computeAngles(total: max(total, 1))
        let colors: [Color] = [.orange, .blue, .green, .pink, .purple, .yellow, .teal, .red]
        ZStack {
            ForEach(0..<angles.count, id: \.self) { i in
                if angles[i].2 > 1 {
                    PieSlice(startAngle: angles[i].0, endAngle: angles[i].1)
                        .fill(colors[i % colors.count])
                }
            }
        }
    }
    private func computeAngles(total: Double) -> [(Angle, Angle, Double)] {
        var r: [(Angle, Angle, Double)] = []
        var s = Angle.degrees(-90)
        for item in data {
            let d = total > 0 ? (item.amount / total) * 360 : 0
            r.append((s, Angle.degrees(s.degrees + d), d))
            s = Angle.degrees(s.degrees + d)
        }
        return r
    }
}

struct PieSlice: Shape {
    let startAngle: Angle; let endAngle: Angle
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var p = Path()
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.closeSubpath()
        return p
    }
}
