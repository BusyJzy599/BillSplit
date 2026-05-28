import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject var vm: GroupDetailViewModel
    @State private var showAddBill = false
    @State private var showReceiptScan = false
    @State private var showLeaveAlert = false

    init(group: BillGroup) {
        _vm = StateObject(wrappedValue: GroupDetailViewModel(group: group))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    InviteCodeCard(code: vm.group.inviteCode)

                    // Members
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("成员 (\(vm.group.memberIds.count))", systemImage: "person.2.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            ForEach(vm.group.memberIds, id: \.self) { id in
                                HStack(spacing: 10) {
                                    AvatarView(avatarUrl: vm.userAvatars[id], displayName: vm.userNames[id] ?? "", size: 36)
                                    Text(vm.userNames[id] ?? "...")
                                        .font(.subheadline)
                                    Spacer()
                                    if id == vm.group.creatorId {
                                        Text("创建者")
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(.tint.opacity(0.1))
                                            .foregroundColor(.accentColor)
                                            .cornerRadius(6)
                                    }
                                }
                                if id != vm.group.memberIds.last { Divider() }
                            }
                        }
                    }

                    if !vm.debts.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("待结算", systemImage: "arrow.left.arrow.right")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                ForEach(vm.debts) { debt in
                                    SettlementRow(debt: debt, userNames: vm.userNames, userAvatars: vm.userAvatars, currentUserId: authVM.currentUserId ?? "", onMarkPaid: {
                                        markPaid(debt: debt)
                                    })
                                    if debt.id != vm.debts.last?.id { Divider() }
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("账单记录", systemImage: "doc.text.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if vm.bills.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "tray")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    Text("还没有账单，点击右上角 + 添加")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                            }
                            ForEach(vm.bills) { bill in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        AvatarView(avatarUrl: vm.userAvatars[bill.payerId], displayName: vm.userNames[bill.payerId] ?? "", size: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(bill.description)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            if bill.currency != CurrencySettings.shared.current.rawValue {
                                                Text("原: \(bill.displayOriginal) · 汇率 \(String(format: "%.2f", bill.exchangeRate))")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text(CurrencySettings.shared.formatted(bill.amount))
                                            .font(.headline)
                                            .foregroundColor(.accentColor)
                                    }
                                    HStack {
                                        Text("付款: \(vm.userNames[bill.payerId] ?? "...")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(bill.createdAt, style: .date)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                                if bill.id != vm.bills.last?.id { Divider() }
                            }
                        }
                    }

                    VStack(spacing: 8) {
                        if vm.group.creatorId == authVM.currentUserId {
                            Button(role: .destructive) {
                                vm.deleteGroup(userId: authVM.currentUserId ?? "")
                            } label: {
                                Label("删除账单组", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button(role: .destructive) {
                                if vm.canLeave(userId: authVM.currentUserId ?? "") {
                                    showLeaveAlert = true
                                } else {
                                    vm.leaveGroup(userId: authVM.currentUserId ?? "")
                                }
                            } label: {
                                Label("退出账单组", systemImage: "rectangle.portrait.and.arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .padding(16)
            }
        }
        .navigationTitle(vm.group.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Menu {
                Button { showAddBill = true } label: {
                    Label("手动输入", systemImage: "keyboard")
                }
                Button { showReceiptScan = true } label: {
                    Label("拍照识别", systemImage: "doc.text.viewfinder")
                }
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showAddBill) {
            AddBillView(groupId: vm.group.id ?? 0, memberIds: vm.group.memberIds, userNames: vm.userNames, currentUserId: authVM.currentUserId ?? "")
        }
        .sheet(isPresented: $showReceiptScan) {
            ReceiptScanView(groupId: vm.group.id ?? 0, memberIds: vm.group.memberIds, userNames: vm.userNames, currentUserId: authVM.currentUserId ?? "")
        }
        .alert("有未结清欠款", isPresented: $showLeaveAlert) {
            Button("取消", role: .cancel) {}
        } message: {
            Text("请先结清所有欠款后再退出账单组")
        }
        .onAppear { vm.loadData() }
        .onDisappear { vm.unsubscribeRealtime() }
    }

    private func markPaid(debt: DebtEntry) {
        guard let groupId = vm.group.id else { return }
        Task {
            try? await SettlementService.shared.createSettlement(
                groupId: groupId, fromUserId: debt.fromUserId,
                toUserId: debt.toUserId, amount: debt.amount
            )
            vm.loadData()
        }
    }
}
