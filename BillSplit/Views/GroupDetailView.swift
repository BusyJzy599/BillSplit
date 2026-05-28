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
        content
            .toast($toast)
            .navigationTitle(vm.group.name)
            .toolbar { toolbarContent }
            .modifier(SheetModifiers(vm: vm, authVM: authVM, showAddBill: $showAddBill, editingBill: $editingBill, showReceiptScan: $showReceiptScan))
            .modifier(AlertModifiers(loc: loc, vm: vm, authVM: authVM, showDeleteConfirm: $showDeleteConfirm, showDeleteGroupAlert: $showDeleteGroupAlert, showLeaveAlert: $showLeaveAlert, deletingBill: $deletingBill, confirmDeleteBill: confirmDeleteBill, confirmDeleteGroup: confirmDeleteGroup))
            .onChange(of: showAddBill) { _, v in if !v { Task { await vm.reload() } } }
            .onChange(of: showReceiptScan) { _, v in if !v { Task { await vm.reload() } } }
            .onChange(of: editingBill) { _, v in if v == nil { Task { await vm.reload() } } }
            .onAppear { vm.loadData() }
            .onDisappear { vm.unsubscribeRealtime() }
    }

    var content: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            List {
                summarySection
                membersSection
                if !vm.debts.isEmpty { debtsSection }
                if !settledHistory.isEmpty { settledSection }
                addButtonsSection
                billsSection
            }
            .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        }
    }

    // MARK: - Sections

    var summarySection: some View {
        Section { summaryView } header: { Text("Summary").font(.subheadline) }
    }

    var membersSection: some View {
        Section { ForEach(vm.group.memberIds, id: \.self, content: memberRow) }
        header: { Text("\(loc.members) (\(vm.group.memberIds.count))").font(.subheadline) }
    }

    var debtsSection: some View {
        Section {
            ForEach(vm.debts) { debt in
                HStack {
                    AvatarView(avatarUrl: vm.userAvatars[debt.fromUserId], displayName: vm.userNames[debt.fromUserId] ?? "", size: 28)
                    Text(vm.userNames[debt.fromUserId] ?? "...").font(.subheadline)
                    Image(systemName: "arrow.right").font(.caption).foregroundColor(.secondary)
                    AvatarView(avatarUrl: vm.userAvatars[debt.toUserId], displayName: vm.userNames[debt.toUserId] ?? "", size: 28)
                    Text(vm.userNames[debt.toUserId] ?? "...").font(.subheadline)
                    Spacer()
                    Text(CurrencySettings.shared.formatted(debt.amount)).font(.subheadline).fontWeight(.semibold)
                    if debt.fromUserId == (authVM.currentUserId ?? "") {
                        Button("Pay") { settle(debt) }.buttonStyle(.borderedProminent).controlSize(.small)
                    }
                }
            }
        } header: { Text("Who Owes Who").font(.subheadline) }
    }

    var settledSection: some View {
        Section {
            ForEach(settledHistory) { s in
                HStack {
                    Text(vm.userNames[s.fromUserId] ?? "...").font(.subheadline)
                    Image(systemName: "arrow.right").font(.caption).foregroundColor(.secondary)
                    Text(vm.userNames[s.toUserId] ?? "...").font(.subheadline)
                    Spacer()
                    Text(CurrencySettings.shared.formatted(s.amount)).font(.subheadline)
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                }
                .foregroundColor(.secondary)
            }
        } header: { Text("Settled").font(.subheadline) }
    }

    // Remove old debtRow and myDebts since we now show all debts

    var addButtonsSection: some View {
        Section {
            HStack(spacing: 12) {
                Button { showAddBill = true } label: { Label("Manual", systemImage: "square.and.pencil").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                Button { showReceiptScan = true } label: { Label("Scan", systemImage: "doc.text.viewfinder").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
            }
        } header: { Text("Add Bill").font(.subheadline) }
    }

    var billsSection: some View {
        Section {
            if vm.bills.isEmpty {
                HStack { Spacer(); Text(loc.noBills).foregroundColor(.secondary); Spacer() }.padding(.vertical, 16)
            }
            ForEach(vm.bills) { bill in billEntry(bill) }
        } header: { if !vm.bills.isEmpty { Text(loc.billRecords).font(.subheadline) } }
    }

    // MARK: - Rows

    var summaryView: some View {
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

    func memberRow(_ id: String) -> some View {
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

    var settledHistory: [Settlement] { vm.settlements.filter { $0.status == .paid } }

    @ViewBuilder func billEntry(_ bill: Bill) -> some View {
        let uid = authVM.currentUserId ?? ""
        let isMyBill = bill.payerId == uid
        let isParticipant = bill.participantIds.contains(uid)
        let myShare = bill.amount / Double(max(bill.participantIds.count, 1))

        VStack(spacing: 6) {
            HStack(spacing: 10) {
                ZStack { Circle().fill(vm.billColor(bill).opacity(0.15)).frame(width: 36, height: 36); Text(vm.billIcon(bill)).font(.system(size: 18)) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(bill.description).font(.subheadline).fontWeight(.medium)
                    HStack(spacing: 4) {
                        Text(isMyBill ? "You paid" : "\(vm.userNames[bill.payerId] ?? "...") paid")
                            .font(.caption).foregroundColor(isMyBill ? .blue : .secondary)
                        if isParticipant && !isMyBill {
                            Text("· Your share: \(CurrencySettings.shared.formatted(myShare))")
                                .font(.caption2).foregroundColor(.orange)
                        }
                    }
                }
                Spacer()
                Text(CurrencySettings.shared.formatted(bill.amount)).font(.headline).foregroundColor(.accentColor)
            }
            HStack {
                Button { editingBill = bill } label: { Label("Edit", systemImage: "pencil").font(.caption) }.buttonStyle(.borderless).foregroundColor(.orange)
                Spacer()
                Button(role: .destructive) { deletingBill = bill; showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash").font(.caption) }.buttonStyle(.borderless)
            }
        }
    }

    @ToolbarContentBuilder var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Menu {
                Button { UIPasteboard.general.string = vm.group.inviteCode; toast = .success("Copied!") }
                    label: { Label("Copy Code", systemImage: "doc.on.doc") }
                Divider()
                if vm.group.creatorId == authVM.currentUserId {
                    Button(role: .destructive) { showDeleteGroupAlert = true } label: { Label(loc.deleteGroup, systemImage: "trash") }
                } else {
                    Button(role: .destructive) {
                        if vm.canLeave(userId: authVM.currentUserId ?? "") { showLeaveAlert = true }
                        else { vm.leaveGroup(userId: authVM.currentUserId ?? "") }
                    } label: { Label(loc.leaveGroup, systemImage: "rectangle.portrait.and.arrow.right") }
                }
            } label: { Image(systemName: "gearshape") }
        }
    }

    // MARK: - Helpers

    // debts are now shown in debtsSection (all debts, not just current user)
    func balanceColor(_ id: String) -> Color {
        let b = vm.memberBalance(id); if abs(b) < 0.01 { return .secondary }; return b > 0 ? .green : .orange
    }
    func settle(_ debt: DebtEntry) {
        guard let groupId = vm.group.id else { return }
        Task {
            do {
                try await SettlementService.shared.createSettlement(groupId: groupId, fromUserId: debt.fromUserId, toUserId: debt.toUserId, amount: debt.amount)
                await MainActor.run { toast = .success("Paid!") }
                await vm.reload()
            } catch {
                await MainActor.run { toast = .error(error.localizedDescription) }
            }
        }
    }
    func confirmDeleteBill() {
        guard let bill = deletingBill, let billId = bill.id else { return }
        Task {
            do { try await BillService.shared.deleteBill(billId); await MainActor.run { toast = .success("Deleted") }; await vm.reload() }
            catch { await MainActor.run { toast = .error(error.localizedDescription) } }
        }
    }
    func confirmDeleteGroup() {
        guard let groupId = vm.group.id else { return }
        Task {
            do {
                try await GroupService.shared.deleteGroup(groupId)
            } catch {
                await MainActor.run { toast = .error(error.localizedDescription) }
            }
        }
    }
}

// MARK: - Modifier helpers (split for type-checker)

struct SheetModifiers: ViewModifier {
    let vm: GroupDetailViewModel; let authVM: AuthViewModel
    @Binding var showAddBill: Bool; @Binding var editingBill: Bill?
    @Binding var showReceiptScan: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showAddBill) {
                AddBillView(groupId: vm.group.id ?? 0, memberIds: vm.group.memberIds, userNames: vm.userNames, currentUserId: authVM.currentUserId ?? "")
            }
            .sheet(item: $editingBill) { bill in
                AddBillView(groupId: vm.group.id ?? 0, memberIds: vm.group.memberIds, userNames: vm.userNames, currentUserId: authVM.currentUserId ?? "", editBill: bill)
            }
            .sheet(isPresented: $showReceiptScan) {
                ReceiptScanView(groupId: vm.group.id ?? 0, memberIds: vm.group.memberIds, userNames: vm.userNames, currentUserId: authVM.currentUserId ?? "")
            }
    }
}

struct AlertModifiers: ViewModifier {
    let loc: LocaleManager; let vm: GroupDetailViewModel; let authVM: AuthViewModel
    @Binding var showDeleteConfirm: Bool; @Binding var showDeleteGroupAlert: Bool
    @Binding var showLeaveAlert: Bool; @Binding var deletingBill: Bill?
    let confirmDeleteBill: () -> Void; let confirmDeleteGroup: () -> Void

    func body(content: Content) -> some View {
        content
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
    }
}
