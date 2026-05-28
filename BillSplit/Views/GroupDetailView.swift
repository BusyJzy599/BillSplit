import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject var vm: GroupDetailViewModel
    @StateObject private var loc = LocaleManager.shared
    @State private var showAddBill = false
    @State private var showReceiptScan = false
    @State private var editingBill: Bill?
    @State private var deletingBill: Bill?
    @State private var showDeleteConfirm = false
    @State private var showDeleteGroupAlert = false
    @State private var showLeaveAlert = false
    @State private var toast: Toast?

    init(group: BillGroup) {
        _vm = StateObject(wrappedValue: GroupDetailViewModel(group: group))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    // Summary
                    summaryCard

                    // Members with balances
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("\(loc.members) (\(vm.group.memberIds.count))", systemImage: "person.2.fill")
                                .font(.subheadline).foregroundColor(.secondary)
                            ForEach(vm.group.memberIds, id: \.self) { id in
                                HStack(spacing: 10) {
                                    AvatarView(avatarUrl: vm.userAvatars[id], displayName: vm.userNames[id] ?? "", size: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(vm.userNames[id] ?? "...").font(.subheadline)
                                        if id == vm.group.creatorId {
                                            Text(loc.creator).font(.caption2).foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(vm.balanceText(id))
                                        .font(.caption).fontWeight(.medium)
                                        .foregroundColor(balanceColor(id))
                                }
                                if id != vm.group.memberIds.last { Divider() }
                            }
                        }
                    }

                    // Debts involving current user
                    if !myDebts.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(loc.toSettle, systemImage: "arrow.left.arrow.right")
                                    .font(.subheadline).foregroundColor(.secondary)
                                ForEach(myDebts) { debt in
                                    SettlementRow(debt: debt, userNames: vm.userNames, userAvatars: vm.userAvatars, currentUserId: authVM.currentUserId ?? "", onMarkPaid: {
                                        markPaid(debt: debt)
                                    })
                                    if debt.id != myDebts.last?.id { Divider() }
                                }
                            }
                        }
                    }

                    // Bills
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(loc.billRecords, systemImage: "doc.text.fill")
                                .font(.subheadline).foregroundColor(.secondary)
                            if vm.bills.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "tray").font(.title2).foregroundColor(.secondary)
                                    Text(loc.noBills).font(.subheadline).foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 20)
                            }
                            ForEach(vm.bills) { bill in
                                billRow(bill)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) { deletingBill = bill; showDeleteConfirm = true }
                                            label: { Label(loc.delete, systemImage: "trash") }
                                        Button { editingBill = bill }
                                            label: { Label(loc.edit, systemImage: "pencil") }
                                        .tint(.orange)
                                    }
                                if bill.id != vm.bills.last?.id { Divider() }
                            }
                        }
                    }

                    Spacer().frame(height: 32)
                }
                .padding(16)
            }
        }
        .toast($toast)
        .navigationTitle(vm.group.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showAddBill = true } label: { Label(loc.manualInput, systemImage: "keyboard") }
                    Button { showReceiptScan = true } label: { Label(loc.scanReceipt, systemImage: "doc.text.viewfinder") }
                } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button {
                        UIPasteboard.general.string = vm.group.inviteCode
                        withAnimation { toast = .success("Copied!") }
                    } label: { Label(loc.copy + " " + loc.inviteCode, systemImage: "doc.on.doc") }
                    Divider()
                    if vm.group.creatorId == authVM.currentUserId {
                        Button(role: .destructive) { showDeleteGroupAlert = true }
                            label: { Label(loc.deleteGroup, systemImage: "trash") }
                    } else {
                        Button(role: .destructive) {
                            if vm.canLeave(userId: authVM.currentUserId ?? "") { showLeaveAlert = true }
                            else { vm.leaveGroup(userId: authVM.currentUserId ?? "") }
                        } label: { Label(loc.leaveGroup, systemImage: "rectangle.portrait.and.arrow.right") }
                    }
                } label: { Image(systemName: "ellipsis") }
            }
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
                    Task {
                        try? await BillService.shared.deleteBill(billId)
                        await MainActor.run { toast = .success("Deleted") }
                        vm.loadData()
                    }
                }
            }
        } message: { Text(loc.deleteBillMsg(deletingBill?.description ?? "")) }
        .alert(loc.deleteGroup, isPresented: $showDeleteGroupAlert) {
            Button(loc.cancel, role: .cancel) {}
            Button(loc.delete, role: .destructive) {
                vm.deleteGroup(userId: authVM.currentUserId ?? "")
            }
        } message: { Text("Delete \"\(vm.group.name)\"? This cannot be undone.") }
        .alert(loc.cannotLeave, isPresented: $showLeaveAlert) {
            Button(loc.cancel, role: .cancel) {}
        } message: { Text(loc.cannotLeaveMsg) }
        .onChange(of: showAddBill) { _, v in if !v { vm.loadData() } }
        .onChange(of: showReceiptScan) { _, v in if !v { vm.loadData() } }
        .onAppear { vm.loadData() }
        .onDisappear { vm.unsubscribeRealtime() }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(CurrencySettings.shared.formatted(vm.totalSpent))
                    .font(.title2).fontWeight(.bold)
                Text("Total").font(.caption).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))

            VStack(spacing: 4) {
                let myBal = vm.memberBalance(authVM.currentUserId ?? "")
                Text(myBal > 0.01 ? "Receivable" : myBal < -0.01 ? "Payable" : "Settled")
                    .font(.title3).fontWeight(.semibold)
                    .foregroundColor(myBal > 0.01 ? .green : myBal < -0.01 ? .orange : .secondary)
                Text(CurrencySettings.shared.formatted(abs(myBal)))
                    .font(.title2).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        }
    }

    // MARK: - Bill Row

    private func billRow(_ bill: Bill) -> some View {
        HStack(spacing: 10) {
            // Emoji avatar
            ZStack {
                Circle().fill(vm.billColor(bill).opacity(0.15)).frame(width: 36, height: 36)
                Text(vm.billIcon(bill)).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.description).font(.subheadline).fontWeight(.medium)
                HStack(spacing: 4) {
                    Text(vm.userNames[bill.payerId] ?? "...").font(.caption).foregroundColor(.secondary)
                    Text("· \(bill.participantIds.count) ppl").font(.caption2).foregroundColor(.secondary)
                    if bill.currency != CurrencySettings.shared.current.rawValue {
                        Text("· \(bill.displayOriginal)").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Text(CurrencySettings.shared.formatted(bill.amount))
                .font(.headline).foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private var myDebts: [DebtEntry] {
        let uid = authVM.currentUserId ?? ""
        return vm.debts.filter { $0.fromUserId == uid || $0.toUserId == uid }
    }

    private func balanceColor(_ userId: String) -> Color {
        let b = vm.memberBalance(userId)
        if abs(b) < 0.01 { return .secondary }
        return b > 0 ? .green : .orange
    }

    private func markPaid(debt: DebtEntry) {
        guard let groupId = vm.group.id else { return }
        Task {
            try? await SettlementService.shared.createSettlement(
                groupId: groupId, fromUserId: debt.fromUserId, toUserId: debt.toUserId, amount: debt.amount)
            await MainActor.run { toast = .success("Marked as paid") }
            vm.loadData()
        }
    }
}
