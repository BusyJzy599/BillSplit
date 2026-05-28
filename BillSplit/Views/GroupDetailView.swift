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
            List {
                // Summary
                Section { summaryRow } header: { Text("Summary").font(.subheadline) }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                // Members
                Section { ForEach(vm.group.memberIds, id: \.self) { id in memberRow(id) } }
                header: { Text("\(loc.members) (\(vm.group.memberIds.count))").font(.subheadline) }

                // Debts
                if !myDebts.isEmpty {
                    Section { ForEach(myDebts) { debt in debtRow(debt) } }
                    header: { Text(loc.toSettle).font(.subheadline) }
                }

                // Add buttons
                Section {
                    HStack(spacing: 12) {
                        Button { showAddBill = true } label: { Label(loc.manualInput, systemImage: "square.and.pencil").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent)
                        Button { showReceiptScan = true } label: { Label(loc.scanReceipt, systemImage: "doc.text.viewfinder").frame(maxWidth: .infinity) }
                            .buttonStyle(.bordered)
                    }
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                // Bills
                Section {
                    if vm.bills.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray").font(.title2).foregroundColor(.secondary)
                            Text(loc.noBills).font(.subheadline).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                    ForEach(vm.bills) { bill in billRow(bill) }
                } header: { Text(loc.billRecords).font(.subheadline) }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .toast($toast)
        .navigationTitle(vm.group.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem {
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
                } label: { Image(systemName: "gearshape") }
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
                    Task { try? await BillService.shared.deleteBill(billId); vm.loadData() }
                    toast = .success("Deleted")
                }
            }
        } message: { Text(loc.deleteBillMsg(deletingBill?.description ?? "")) }
        .alert(loc.deleteGroup, isPresented: $showDeleteGroupAlert) {
            Button(loc.cancel, role: .cancel) {}
            Button(loc.delete, role: .destructive) { vm.deleteGroup(userId: authVM.currentUserId ?? "") }
        } message: { Text("Delete \"\(vm.group.name)\"? This cannot be undone.") }
        .alert(loc.cannotLeave, isPresented: $showLeaveAlert) {
            Button(loc.cancel, role: .cancel) {}
        } message: { Text(loc.cannotLeaveMsg) }
        .onChange(of: showAddBill) { _, v in if !v { vm.loadData() } }
        .onChange(of: showReceiptScan) { _, v in if !v { vm.loadData() } }
        .onAppear { vm.loadData() }
        .onDisappear { vm.unsubscribeRealtime() }
    }

    // MARK: - Rows

    private var summaryRow: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(CurrencySettings.shared.formatted(vm.totalSpent)).font(.title3).fontWeight(.bold)
                Text("Total").font(.caption).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 8)
            VStack(spacing: 4) {
                let bal = vm.memberBalance(authVM.currentUserId ?? "")
                Text(bal > 0.01 ? "Receivable" : bal < -0.01 ? "Payable" : "Settled")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(bal > 0.01 ? .green : bal < -0.01 ? .orange : .secondary)
                Text(CurrencySettings.shared.formatted(abs(bal))).font(.title3).fontWeight(.bold)
            }.frame(maxWidth: .infinity).padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func memberRow(_ id: String) -> some View {
        HStack(spacing: 10) {
            AvatarView(avatarUrl: vm.userAvatars[id], displayName: vm.userNames[id] ?? "", size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.userNames[id] ?? "...").font(.subheadline)
                if id == vm.group.creatorId { Text(loc.creator).font(.caption2).foregroundColor(.secondary) }
            }
            Spacer()
            Text(vm.balanceText(id)).font(.caption).fontWeight(.medium).foregroundColor(balanceColor(id))
        }
    }

    @ViewBuilder
    private func debtRow(_ debt: DebtEntry) -> some View {
        SettlementRow(debt: debt, userNames: vm.userNames, userAvatars: vm.userAvatars, currentUserId: authVM.currentUserId ?? "", onMarkPaid: { markPaid(debt: debt) })
    }

    @ViewBuilder
    private func billRow(_ bill: Bill) -> some View {
        HStack(spacing: 10) {
            ZStack { Circle().fill(vm.billColor(bill).opacity(0.15)).frame(width: 36, height: 36); Text(vm.billIcon(bill)).font(.system(size: 18)) }
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.description).font(.subheadline).fontWeight(.medium)
                HStack(spacing: 4) {
                    Text(vm.userNames[bill.payerId] ?? "...").font(.caption).foregroundColor(.secondary)
                    Text("· \(bill.participantIds.count)").font(.caption2).foregroundColor(.secondary)
                    if bill.currency != CurrencySettings.shared.current.rawValue {
                        Text("· \(bill.displayOriginal)").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Text(CurrencySettings.shared.formatted(bill.amount)).font(.headline).foregroundColor(.accentColor)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deletingBill = bill; showDeleteConfirm = true } label: { Label(loc.delete, systemImage: "trash") }
            Button { editingBill = bill } label: { Label(loc.edit, systemImage: "pencil") }.tint(.orange)
        }
    }

    // MARK: - Helpers

    private var myDebts: [DebtEntry] {
        let uid = authVM.currentUserId ?? ""
        return vm.debts.filter { $0.fromUserId == uid || $0.toUserId == uid }
    }
    private func balanceColor(_ id: String) -> Color {
        let b = vm.memberBalance(id); if abs(b) < 0.01 { return .secondary }; return b > 0 ? .green : .orange
    }
    private func markPaid(debt: DebtEntry) {
        guard let groupId = vm.group.id else { return }
        Task {
            try? await SettlementService.shared.createSettlement(groupId: groupId, fromUserId: debt.fromUserId, toUserId: debt.toUserId, amount: debt.amount)
            await MainActor.run { toast = .success("Marked as paid") }
            vm.loadData()
        }
    }
}
