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
        ScrollView {
            VStack(spacing: 16) {
                InviteCodeCard(code: vm.group.inviteCode)

                // Members section
                GlassCard {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("成员 (\(vm.group.memberIds.count))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ForEach(vm.group.memberIds, id: \.self) { id in
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(id == vm.group.creatorId ? .accentColor : .secondary)
                                Text(vm.userNames[id] ?? "...")
                                if id == vm.group.creatorId { Text("创建者").font(.caption2).foregroundColor(.secondary) }
                            }
                        }
                    }
                }

                // Debts section
                if !vm.debts.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("结算")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            ForEach(vm.debts) { debt in
                                SettlementRow(debt: debt, userNames: vm.userNames, currentUserId: authVM.currentUserId ?? "", onMarkPaid: {
                                    markPaid(debt: debt)
                                })
                            }
                        }
                    }
                }

                // Bills section
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("账单")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if vm.bills.isEmpty {
                            Text("暂无账单").foregroundColor(.secondary)
                        }
                        ForEach(vm.bills) { bill in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(bill.description)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(String(format: "¥%.2f", bill.amount))
                                        .fontWeight(.semibold)
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

                // Actions
                VStack(spacing: 8) {
                    if vm.group.creatorId == authVM.currentUserId {
                        Button(role: .destructive) {
                            vm.deleteGroup(userId: authVM.currentUserId ?? "")
                        } label: {
                            Label("删除账单组", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            if vm.canLeave(userId: authVM.currentUserId ?? "") {
                                showLeaveAlert = true
                            } else {
                                vm.leaveGroup(userId: authVM.currentUserId ?? "")
                            }
                        } label: {
                            Label("退出账单组", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(vm.group.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Menu {
                Button {
                    showAddBill = true
                } label: {
                    Label("手动输入", systemImage: "keyboard")
                }
                Button {
                    showReceiptScan = true
                } label: {
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
            ReceiptScanView(
                groupId: vm.group.id ?? 0,
                memberIds: vm.group.memberIds,
                userNames: vm.userNames,
                currentUserId: authVM.currentUserId ?? ""
            )
        }
        .alert("有未结清欠款", isPresented: $showLeaveAlert) {
            Button("取消", role: .cancel) {}
        } message: {
            Text("请先结清所有欠款后再退出账单组")
        }
        .onAppear { vm.loadData() }
    }

    private func markPaid(debt: DebtEntry) {
        guard let groupId = vm.group.id else { return }
        Task {
            try? await SettlementService.shared.createSettlement(
                groupId: groupId, fromUserId: debt.fromUserId,
                toUserId: debt.toUserId, amount: debt.amount
            )
        }
    }
}
