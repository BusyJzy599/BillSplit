import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if vm.isLoading {
                    ProgressView("加载中...")
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Summary cards
                            summaryCards

                            // Heatmap
                            heatmapCard

                            // Pie chart
                            if !vm.categoryBreakdown.isEmpty {
                                pieChartCard
                            }

                            // Category list
                            if !vm.categoryBreakdown.isEmpty {
                                categoryList
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("账单概览")
            .onAppear {
                if let uid = authVM.currentUserId {
                    vm.load(userId: uid)
                }
            }
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            SummaryCard(title: "总支出", value: String(format: "¥%.0f", vm.totalPaid), icon: "yensign.circle.fill", color: .orange)
            SummaryCard(title: "账单数", value: "\(vm.totalBills)", icon: "doc.text.fill", color: .blue)
            SummaryCard(title: "账单组", value: "\(vm.totalGroups)", icon: "person.3.fill", color: .green)
        }
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("消费热力图", systemImage: "calendar")
                .font(.subheadline)
                .foregroundColor(.secondary)

            let data = vm.dailySpending
            let columns = 7
            let rows = Int(ceil(Double(data.count) / Double(columns)))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: columns), spacing: 3) {
                ForEach(0..<data.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(vm.heatmapColor(for: data[i].amount))
                        .frame(height: 16)
                }
            }

            // Legend
            HStack(spacing: 6) {
                Text("少")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.systemGray6))
                    .frame(width: 12, height: 12)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.green.opacity(0.3))
                    .frame(width: 12, height: 12)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.green.opacity(0.6))
                    .frame(width: 12, height: 12)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.green)
                    .frame(width: 12, height: 12)
                Text("多")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    // MARK: - Pie Chart

    private var pieChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("支出分类", systemImage: "chart.pie.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                PieChartView(data: vm.categoryBreakdown)
                    .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(vm.categoryBreakdown.prefix(5), id: \.name) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(pieColor(for: item.name))
                                .frame(width: 8, height: 8)
                            Text(item.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "¥%.0f", item.amount))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    // MARK: - Category List

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("分类明细", systemImage: "list.bullet.rectangle")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(vm.categoryBreakdown, id: \.name) { item in
                HStack {
                    Circle()
                        .fill(pieColor(for: item.name))
                        .frame(width: 10, height: 10)
                    Text(item.name)
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "¥%.2f", item.amount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(String(format: "%.0f%%", vm.totalPaid > 0 ? item.amount / vm.totalPaid * 100 : 0))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                if item.name != vm.categoryBreakdown.last?.name { Divider() }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    // MARK: - Pie colors

    private func pieColor(for name: String) -> Color {
        let colors: [Color] = [.orange, .blue, .green, .pink, .purple, .yellow, .teal, .red]
        let idx = vm.categoryBreakdown.firstIndex(where: { $0.name == name }) ?? 0
        return colors[idx % colors.count]
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }
}

// MARK: - Pie Chart View

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
                    if angles[i].2 > 1 { // skip tiny slices
                        PieSlice(center: center, radius: radius, startAngle: angles[i].0, endAngle: angles[i].1)
                            .fill(colors[i % colors.count])
                    }
                }
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: radius * 0.6, height: radius * 0.6)
                VStack(spacing: 0) {
                    Text("总计")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(String(format: "¥%.0f", total))
                        .font(.system(size: 11, weight: .bold))
                }
            }
        }
    }

    private func computeAngles(total: Double) -> [(Angle, Angle, Double)] {
        var result: [(Angle, Angle, Double)] = []
        var start = Angle.degrees(-90)
        for item in data {
            let degrees = total > 0 ? (item.amount / total) * 360 : 0
            let end = Angle.degrees(start.degrees + degrees)
            result.append((start, end, degrees))
            start = end
        }
        return result
    }
}

// MARK: - Pie Slice

struct PieSlice: Shape {
    let center: CGPoint
    let radius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}
