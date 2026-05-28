import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject var vm: GroupDetailViewModel
    @StateObject private var loc = LocaleManager.shared
    @State private var showAddBill = false
    @State private var showReceiptScan = false
    @State private var showLeaveAlert = false
    @State private var editingBill: Bill?
    @State private var deletingBill: Bill?
    @State private var showDeleteConfirm = false

    init(group: BillGroup) {
        _vm = StateObject(wrappedValue: GroupDetailViewModel(group: group))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    InviteCodeCard(code: vm.group.inviteCode)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("\(loc.members) (\(vm.group.memberIds.count))", systemImage: "person.2.fill")
                                .font(.subheadline).foregroundColor(.secondary)
                            ForEach(vm.group.memberIds, id: \.self) { id in
                                HStack(spacing: 10) {
                                    AvatarView(avatarUrl: vm.userAvatars[id], displayName: vm.userNames[id] ?? "", size: 36)
                                    Text(vm.userNames[id] ?? "...").font(.subheadline)
                                    Spacer()
                                    if id == vm.group.creatorId {
                                        Text(loc.creator)
                                            .font(.caption2)
                                            .padding(.horizontal, 8).padding(.vertical, 3)
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
                                Label(loc.toSettle, systemImage: "arrow.left.arrow.right")
                                    .font(.subheadline).foregroundColor(.secondary)
                                ForEach(vm.debts) { debt in
                                    SettlementRow(debt: debt, userNames: vm.userNames, userAvatars: vm.userAvatars, currentUserId: authVM.currentUserId ?? "", onMarkPaid: { markPaid(debt: debt) })
                                    if debt.id != vm.debts.last?.id { Divider() }
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(loc.billRecords, systemImage: "doc.text.fill")
                                .font(.subheadline).foregroundColor(.secondary)
                            if vm.bills.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "tray").font(.title2).foregroundColor(.secondary)
                                    Text(loc.noBills).font(.subheadline).foregroundColor(.secondary)
                                    Text(loc.noBillsHint).font(.caption).foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 20)
                            }
                            ForEach(vm.bills) { bill in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        AvatarView(avatarUrl: vm.userAvatars[bill.payerId], displayName: vm.userNames[bill.payerId] ?? "", size: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(bill.description).font(.subheadline).fontWeight(.medium)
                                            if bill.currency != CurrencySettings.shared.current.rawValue {
                                                Text("\(bill.displayOriginal) · rate \(String(format: "%.2f", bill.exchangeRate))")
                                                    .font(.caption2).foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text(CurrencySettings.shared.formatted(bill.amount))
                                            .font(.headline).foregroundColor(.accentColor)
                                    }
                                    HStack {
                                        Text("\(loc.pay) \(vm.userNames[bill.payerId] ?? "...")")
                                            .font(.caption).foregroundColor(.secondary)
                                        Spacer()
                                        Text(bill.createdAt, style: .date)
                                            .font(.caption2).foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture { editingBill = bill }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deletingBill = bill; showDeleteConfirm = true
                                    } label: { Label(loc.delete, systemImage: "trash") }
                                    Button {
                                        editingBill = bill
                                    } label: { Label(loc.edit, systemImage: "pencil") }
                                    .tint(.orange)
                                }
                                if bill.id != vm.bills.last?.id { Divider() }
                            }
                        }
                    }

                    VStack(spacing: 8) {
                        if vm.group.creatorId == authVM.currentUserId {
                            Button(role: .destructive) {
                                vm.deleteGroup(userId: authVM.currentUserId ?? "")
                            } label: {
                                Label(loc.deleteGroup, systemImage: "trash").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button(role: .destructive) {
                                if vm.canLeave(userId: authVM.currentUserId ?? "") { showLeaveAlert = true }
                                else { vm.leaveGroup(userId: authVM.currentUserId ?? "") }
                            } label: {
                                Label(loc.leaveGroup, systemImage: "rectangle.portrait.and.arrow.right").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.top, 8).padding(.bottom, 32)
                }
                .padding(16)
            }
        }
        .navigationTitle(vm.group.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Menu {
                Button { showAddBill = true } label: { Label(loc.manualInput, systemImage: "keyboard") }
                Button { showReceiptScan = true } label: { Label(loc.scanReceipt, systemImage: "doc.text.viewfinder") }
            } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showAddBill) {
            AddBillView(groupId: vm.group.id ?? 0, memberIds: vm.group.memberIds, userNames: vm.userNames, currentUserId: authVM.currentUserId ?? "")
        }
        .sheet(item: $editingBill) { bill in
            AddBillView(groupId: vm.group.id ?? 0, memberIds: vm.group.memberIds, userNames: vm.userNames, currentUserId: authVM.currentUserId ?? "", editBill: bill)
        }
        .sheet(isPresented: $showReceiptScan) {
            ReceiptScanView(groupId: vm.group.id ?? 0, memberIds: vm.group.memberIds, userNames: vm.userNames, currentUserId: authVM.currentUserId ?? "")
        }
        .alert(loc.deleteBillTitle, isPresented: $showDeleteConfirm) {
            Button(loc.cancel, role: .cancel) {}
            Button(loc.delete, role: .destructive) {
                if let bill = deletingBill, let billId = bill.id {
                    Task { try? await BillService.shared.deleteBill(billId); vm.loadData() }
                }
            }
        } message: { Text(loc.deleteBillMsg(deletingBill?.description ?? "")) }
        .alert(loc.cannotLeave, isPresented: $showLeaveAlert) {
            Button(loc.cancel, role: .cancel) {}
        } message: { Text(loc.cannotLeaveMsg) }
        .onChange(of: showAddBill) { _, newValue in if !newValue { vm.loadData() } }
        .onChange(of: showReceiptScan) { _, newValue in if !newValue { vm.loadData() } }
        .onAppear { vm.loadData() }
        .onDisappear { vm.unsubscribeRealtime() }
    }

    private func markPaid(debt: DebtEntry) {
        guard let groupId = vm.group.id else { return }
        Task {
            try? await SettlementService.shared.createSettlement(
                groupId: groupId, fromUserId: debt.fromUserId, toUserId: debt.toUserId, amount: debt.amount)
            vm.loadData()
        }
    }
}
