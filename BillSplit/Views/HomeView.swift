import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = HomeViewModel()
    @StateObject private var loc = LocaleManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if vm.isLoading {
                    ProgressView(loc.loading)
                } else if vm.allBills.isEmpty && vm.allGroups.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis").font(.system(size: 50)).foregroundColor(.secondary)
                        Text("No data yet").font(.title3).fontWeight(.medium)
                        Text("Add bills to see your spending analysis").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
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
                }
            }
            .navigationTitle(loc.navHome)
            .onAppear { if let uid = authVM.currentUserId { vm.load(userId: uid) } }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("refreshGroups"))) { _ in
                if let uid = authVM.currentUserId { vm.load(userId: uid) }
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        HStack(spacing: 12) {
            statCard(value: CurrencySettings.shared.formatted(vm.totalPaid), label: loc.totalSpent, icon: "dollarsign.circle.fill", color: .orange)
            statCard(value: "\(vm.totalBills)", label: loc.billCount, icon: "doc.text.fill", color: .blue)
            statCard(value: "\(vm.totalGroups)", label: loc.groupCount, icon: "person.3.fill", color: .green)
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.headline).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
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
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: cols), spacing: 2) {
            ForEach(0..<data.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(heatmapCellColor(data[i].amount))
                    .frame(height: 14)
            }
        }
    }

    private func heatmapCellColor(_ amount: Double) -> Color {
        let maxAmount = vm.dailySpending.map(\.amount).max() ?? 1
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
            HStack(spacing: 16) {
                PieChartView(data: vm.categoryBreakdown).frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(vm.categoryBreakdown.prefix(4), id: \.name) { item in
                        HStack(spacing: 6) {
                            Circle().fill(pieColor(item.name)).frame(width: 6, height: 6)
                            Text(item.name).font(.caption).foregroundColor(.secondary)
                            Text(CurrencySettings.shared.formatted(item.amount)).font(.caption).fontWeight(.medium)
                        }
                    }
                }
            }
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

// MARK: - Summary Card (not used, kept for compatibility)

struct SummaryCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(value).font(.title3).fontWeight(.bold)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.04), radius: 6))
    }
}

// MARK: - Pie Chart

struct PieChartView: View {
    let data: [(name: String, amount: Double)]
    var body: some View {
        GeometryReader { geo in
            let total = data.map(\.amount).reduce(0, +)
            let angles = computeAngles(total: max(total, 1))
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            let colors: [Color] = [.orange, .blue, .green, .pink, .purple, .yellow, .teal, .red]
            ZStack {
                ForEach(0..<angles.count, id: \.self) { i in
                    if angles[i].2 > 1 {
                        PieSlice(center: center, radius: radius, startAngle: angles[i].0, endAngle: angles[i].1)
                            .fill(colors[i % colors.count])
                    }
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
    let center: CGPoint; let radius: CGFloat; let startAngle: Angle; let endAngle: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.closeSubpath()
        return p
    }
}
