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
                Section { summaryView }
                header: { Text("Summary").font(.subheadline) }

                Section {
                    ForEach(vm.group.memberIds, id: \.self, content: memberView)
                } header: { Text("\(loc.members) (\(vm.group.memberIds.count))").font(.subheadline) }

                if !myDebts.isEmpty {
                    Section {
                        ForEach(myDebts) { debt in
                            SettlementRow(debt: debt, userNames: vm.userNames, userAvatars: vm.userAvatars, currentUserId: authVM.currentUserId ?? "", onMarkPaid: { settle(debt) })
                        }
                    } header: { Text(loc.toSettle).font(.subheadline) }
                }

                Section {
                    HStack(spacing: 12) {
                        Button { showAddBill = true } label: { Label(loc.manualInput, systemImage: "square.and.pencil").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                        Button { showReceiptScan = true } label: { Label(loc.scanReceipt, systemImage: "doc.text.viewfinder").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    }
                } header: { Text("Add Bill").font(.subheadline) }

                Section {
                    if vm.bills.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray").font(.title2).foregroundColor(.secondary)
                            Text(loc.noBills).font(.subheadline).foregroundColor(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                    ForEach(vm.bills) { bill in
                        VStack(spacing: 6) {
                            HStack(spacing: 10) {
                                ZStack { Circle().fill(vm.billColor(bill).opacity(0.15)).frame(width: 36, height: 36); Text(vm.billIcon(bill)).font(.system(size: 18)) }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bill.description).font(.subheadline).fontWeight(.medium)
                                    HStack(spacing: 4) {
                                        Text("Paid by \(vm.userNames[bill.payerId] ?? "...")").font(.caption).foregroundColor(.secondary)
                                        if bill.currency != CurrencySettings.shared.current.rawValue {
                                            Text("· \(bill.displayOriginal)").font(.caption2).foregroundColor(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                                Text(CurrencySettings.shared.formatted(bill.amount)).font(.headline).foregroundColor(.accentColor)
                            }
                            HStack(spacing: 0) {
                                Button { editingBill = bill } label: {
                                    Label(loc.edit, systemImage: "pencil").font(.caption)
                                }.buttonStyle(.borderless).foregroundColor(.orange)
                                Spacer()
                                Button(role: .destructive) { deletingBill = bill; showDeleteConfirm = true } label: {
                                    Label(loc.delete, systemImage: "trash").font(.caption)
                                }.buttonStyle(.borderless)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deletingBill = bill
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showDeleteConfirm = true }
                            } label: { Label(loc.delete, systemImage: "trash") }
                            Button {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { editingBill = bill }
                            } label: { Label(loc.edit, systemImage: "pencil") }.tint(.orange)
                        }
                    }
                } header: { if !vm.bills.isEmpty { Text(loc.billRecords).font(.subheadline) } }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .toast($toast)
        .navigationTitle(vm.group.name)
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
            Button(loc.delete, role: .destructive) { confirmDeleteBill() }
        } message: { Text(loc.deleteBillMsg(deletingBill?.description ?? "")) }
        .alert(loc.deleteGroup, isPresented: $showDeleteGroupAlert) {
            Button(loc.cancel, role: .cancel) {}
            Button(loc.delete, role: .destructive) { confirmDeleteGroup() }
        } message: { Text("Delete \"\(vm.group.name)\"? This cannot be undone.") }
        .alert(loc.cannotLeave, isPresented: $showLeaveAlert) {
            Button(loc.cancel, role: .cancel) {}
        } message: { Text(loc.cannotLeaveMsg) }
        .onChange(of: showAddBill) { _, v in if !v { Task { await vm.reload() } } }
        .onChange(of: showReceiptScan) { _, v in if !v { Task { await vm.reload() } } }
        .onAppear { vm.loadData() }
        .onDisappear { vm.unsubscribeRealtime() }
    }

    // MARK: - Views

    private var summaryView: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(CurrencySettings.shared.formatted(vm.totalSpent)).font(.title3).fontWeight(.bold)
                Text("Total").font(.caption).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 8)
            VStack(spacing: 2) {
                let bal = vm.memberBalance(authVM.currentUserId ?? "")
                Text(bal > 0.01 ? "Receivable" : bal < -0.01 ? "Payable" : "Settled")
                    .font(.caption).fontWeight(.semibold).foregroundColor(bal > 0.01 ? .green : bal < -0.01 ? .orange : .secondary)
                Text(CurrencySettings.shared.formatted(abs(bal))).font(.title3).fontWeight(.bold)
            }.frame(maxWidth: .infinity).padding(.vertical, 8)
        }
    }

    private func memberView(_ id: String) -> some View {
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

    // MARK: - Helpers

    private var myDebts: [DebtEntry] {
        let uid = authVM.currentUserId ?? ""
        return vm.debts.filter { $0.fromUserId == uid || $0.toUserId == uid }
    }
    private func balanceColor(_ id: String) -> Color {
        let b = vm.memberBalance(id); if abs(b) < 0.01 { return .secondary }; return b > 0 ? .green : .orange
    }
    private func settle(_ debt: DebtEntry) {
        guard let groupId = vm.group.id else { return }
        Task {
            try? await SettlementService.shared.createSettlement(groupId: groupId, fromUserId: debt.fromUserId, toUserId: debt.toUserId, amount: debt.amount)
            await MainActor.run { toast = .success("Marked as paid") }
            await vm.reload()
        }
    }
    private func confirmDeleteBill() {
        guard let bill = deletingBill, let billId = bill.id else { return }
        Task {
            do {
                try await BillService.shared.deleteBill(billId)
                await MainActor.run { toast = .success("Deleted") }
                await vm.reload()
            } catch {
                await MainActor.run { toast = .error(error.localizedDescription) }
            }
        }
    }
    private func confirmDeleteGroup() {
        guard let groupId = vm.group.id else { return }
        Task {
            try? await GroupService.shared.deleteGroup(groupId)
        }
    }
}
