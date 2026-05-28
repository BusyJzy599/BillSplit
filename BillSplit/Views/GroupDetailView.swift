import SwiftUI

struct GroupDetailView: View {
    @Environment(\.dismiss) var dismiss
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
    @State private var showLeaveConfirmAlert = false
    @State private var toast: Toast?
    @State private var settlingIds = Set<UUID>()
    @State private var showAllSettled = false
    @State private var revokingSettlementId: Int?
    @State private var removingMemberId: String?

    init(group: BillGroup) {
        _vm = StateObject(wrappedValue: GroupDetailViewModel(group: group))
    }

    var body: some View {
        content
            .toast($toast)
            .navigationTitle(vm.group.name)
            .toolbar { toolbarContent }
            .modifier(SheetModifiers(vm: vm, authVM: authVM, showAddBill: $showAddBill, editingBill: $editingBill, showReceiptScan: $showReceiptScan))
            .modifier(AlertModifiers(loc: loc, vm: vm, authVM: authVM, showDeleteConfirm: $showDeleteConfirm, showDeleteGroupAlert: $showDeleteGroupAlert, showLeaveConfirmAlert: $showLeaveConfirmAlert, showLeaveAlert: $showLeaveAlert, deletingBill: $deletingBill, confirmDeleteBill: confirmDeleteBill, confirmDeleteGroup: confirmDeleteGroup))
            .onChange(of: showAddBill) { _, v in if !v { Task { await vm.reload() } } }
            .onChange(of: showReceiptScan) { _, v in if !v { Task { await vm.reload() } } }
            .onChange(of: editingBill) { _, v in if v == nil { Task { await vm.reload() } } }
            .onAppear { vm.loadData() }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("currencyChanged"))) { _ in vm.objectWillChange.send() }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("localeChanged"))) { _ in vm.objectWillChange.send() }
            .alert(loc.revokeSettlementTitle, isPresented: Binding(
                get: { revokingSettlementId != nil },
                set: { if !$0 { revokingSettlementId = nil } }
            )) {
                Button(loc.cancel, role: .cancel) { revokingSettlementId = nil }
                Button(loc.revoke, role: .destructive) { confirmRevokeSettlement() }
            } message: {
                Text(loc.revokeSettlementMsg)
            }
            .alert(loc.locale == .zh ? "移除成员" : "Remove member", isPresented: Binding(
                get: { removingMemberId != nil },
                set: { if !$0 { removingMemberId = nil } }
            )) {
                Button(loc.cancel, role: .cancel) { removingMemberId = nil }
                Button(loc.locale == .zh ? "移除" : "Remove", role: .destructive) { confirmRemoveMember() }
            } message: {
                if let mid = removingMemberId {
                    Text(loc.locale == .zh ? "确定要移除 \(vm.userNames[mid] ?? "...") 吗？" : "Remove \(vm.userNames[mid] ?? "...") from this group?")
                }
            }
            .onDisappear { vm.unsubscribeRealtime() }
    }

    var content: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            List {
                summarySection
                membersSection
                if !vm.bills.isEmpty { debtsSection }
                if !settledHistory.isEmpty { settledSection }
                addButtonsSection
                billsSection
            }
            .listStyle(.insetGrouped).scrollContentBackground(.hidden)
            .refreshable { await vm.reload() }
            .overlay(alignment: .top) {
                if vm.isReloading {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text(loc.loading).font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial).cornerRadius(12)
                    .padding(.top, 8)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: vm.isReloading)
        }
    }

    // MARK: - Sections

    var summarySection: some View {
        Section { summaryView } header: { Text(loc.summary).font(.subheadline) }
    }

    var membersSection: some View {
        Section { ForEach(vm.group.memberIds, id: \.self, content: memberRow) }
        header: { Text("\(loc.members) (\(vm.group.memberIds.count))").font(.subheadline) }
    }

    var debtsSection: some View {
        Section {
            if vm.debts.isEmpty && !vm.bills.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("🎉").font(.title).scaleEffect(1.0).animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: vm.debts.isEmpty)
                        Text(loc.allSettled).font(.subheadline).foregroundColor(.green).fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            ForEach(vm.debts) { debt in
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        AvatarView(avatarUrl: vm.userAvatars[debt.fromUserId], displayName: vm.userNames[debt.fromUserId] ?? "", size: 26)
                        Text(vm.userNames[debt.fromUserId] ?? "...").font(.subheadline).fontWeight(.medium)
                        Spacer()
                        Text(CurrencySettings.shared.formatted(debt.amount)).font(.subheadline).fontWeight(.bold).foregroundColor(.orange)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.turn.right.down").font(.caption2).foregroundColor(.secondary).padding(.leading, 13)
                        AvatarView(avatarUrl: vm.userAvatars[debt.toUserId], displayName: vm.userNames[debt.toUserId] ?? "", size: 20)
                        Text(vm.userNames[debt.toUserId] ?? "...").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        if debt.fromUserId == (authVM.currentUserId ?? "") {
                            Button { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); settle(debt) }
                                label: {
                                    if settlingIds.contains(debt.id) {
                                        ProgressView().scaleEffect(0.6).tint(.white)
                                    } else {
                                        Text(loc.payButton).font(.caption2).foregroundColor(.white)
                                    }
                                }
                                .buttonStyle(.borderedProminent).controlSize(.mini)
                                .disabled(settlingIds.contains(debt.id))
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        } header: { if !vm.debts.isEmpty { Text(loc.whoOwesWho).font(.subheadline) } }
    }

    @ViewBuilder var settledSection: some View {
        let history = settledHistory
        let display = showAllSettled ? history : Array(history.prefix(3))
        Section {
            ForEach(display) { s in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                    Text("\(vm.userNames[s.fromUserId] ?? "...") → \(vm.userNames[s.toUserId] ?? "...")").font(.caption)
                    Spacer()
                    Text(CurrencySettings.shared.formatted(s.amount)).font(.caption).fontWeight(.medium)
                    if let sid = s.id {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            revokingSettlementId = sid
                        } label: {
                            Image(systemName: "arrow.uturn.backward").font(.caption2).foregroundColor(.red)
                        }
                    }
                }
            }
            if history.count > 3 {
                Button(showAllSettled ? loc.showLess : loc.showAll(history.count)) {
                    withAnimation { showAllSettled.toggle() }
                }.font(.caption).foregroundColor(.accentColor)
            }
        } header: { Text(loc.settled).font(.subheadline) }
    }

    // All debts and settled history shown in their respective sections

    var addButtonsSection: some View {
        Section {
            HStack(spacing: 12) {
                Button { showAddBill = true } label: {
                    HStack { Spacer(); Label(loc.manual, systemImage: "square.and.pencil"); Spacer() }.foregroundColor(.white)
                }.buttonStyle(.borderedProminent).tint(.accentColor)
                Button { showReceiptScan = true } label: {
                    HStack { Spacer(); Label(loc.scan, systemImage: "doc.text.viewfinder"); Spacer() }
                }.buttonStyle(.bordered).tint(.accentColor)
            }
        } header: { Text(loc.addBill).font(.subheadline) }
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
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill").font(.title3).foregroundStyle(.blue)
                Text(CurrencySettings.shared.formatted(vm.totalSpent)).font(.headline).fontWeight(.bold)
                Text(loc.totalSpent).font(.caption2).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 10)
            Divider()
            VStack(spacing: 4) {
                let bal = vm.memberBalance(authVM.currentUserId ?? "")
                Image(systemName: bal > 0.01 ? "arrow.down.circle.fill" : bal < -0.01 ? "arrow.up.circle.fill" : "checkmark.circle.fill")
                    .font(.title3).foregroundStyle(bal > 0.01 ? .green : bal < -0.01 ? .orange : .secondary)
                Text(CurrencySettings.shared.formatted(abs(bal))).font(.headline).fontWeight(.bold)
                Text(bal > 0.01 ? loc.youReceive : bal < -0.01 ? loc.youOwe : loc.settledStatus)
                    .font(.caption2).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 10)
        }
    }

    @ViewBuilder func memberRow(_ id: String) -> some View {
        let isCreator = vm.group.creatorId == authVM.currentUserId
        HStack(spacing: 10) {
            AvatarView(avatarUrl: vm.userAvatars[id], displayName: vm.userNames[id] ?? "", size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.userNames[id] ?? "...").font(.subheadline)
                HStack(spacing: 4) {
                    if id == vm.group.creatorId { Text(loc.creator).font(.caption2).foregroundColor(.secondary) }
                }
            }
            Spacer()
            let bal = vm.memberBalance(id)
            if abs(bal) > 0.01 {
                Text(vm.balanceText(id)).font(.caption).fontWeight(.semibold)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(bal > 0 ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .foregroundColor(bal > 0 ? .green : .orange)
                    .cornerRadius(6)
            } else {
                Image(systemName: "checkmark").font(.caption2).foregroundColor(.secondary)
            }
        }
        .swipeActions(edge: .trailing) {
            if isCreator && id != authVM.currentUserId {
                Button(role: .destructive) {
                    removingMemberId = id
                } label: { Label(loc.locale == .zh ? "移除" : "Remove", systemImage: "person.fill.xmark") }
            }
        }
    }

    var settledHistory: [Settlement] {
        vm.settlements.filter { $0.status == .paid }.sorted { ($0.id ?? 0) > ($1.id ?? 0) }
    }

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
                        Text(isMyBill ? loc.youPaid : "\(vm.userNames[bill.payerId] ?? "...") \(loc.pay)")
                            .font(.caption).foregroundColor(isMyBill ? .blue : .secondary)
                        Text("· \(bill.createdAt, style: .date)").font(.caption2).foregroundColor(.secondary)
                        if isParticipant && !isMyBill {
                            Text(loc.yourShareAmount(CurrencySettings.shared.formatted(myShare)))
                                .font(.caption2).foregroundColor(.orange)
                        }
                    }
                }
                Spacer()
                Text(CurrencySettings.shared.formatted(bill.amount)).font(.headline).foregroundColor(.accentColor)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                deletingBill = bill; showDeleteConfirm = true
            } label: { Label(loc.delete, systemImage: "trash") }
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                editingBill = bill
            } label: { Label(loc.edit, systemImage: "pencil") }.tint(.accentColor)
        }
    }

    @ToolbarContentBuilder var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Menu {
                Button { UIPasteboard.general.string = vm.group.inviteCode; toast = .success(loc.toastCopied) }
                    label: { Label(loc.copyCode, systemImage: "doc.on.doc") }
                Button { shareSummary() }
                    label: { Label(loc.locale == .zh ? "分享账单摘要" : "Share Summary", systemImage: "square.and.arrow.up") }
                Divider()
                if vm.group.creatorId == authVM.currentUserId {
                    Button(role: .destructive) { showDeleteGroupAlert = true } label: { Label(loc.deleteGroup, systemImage: "trash") }
                } else {
                    Button(role: .destructive) {
                        let uid = authVM.currentUserId ?? ""
                        if vm.canLeave(userId: uid) { showLeaveAlert = true }
                        else { showLeaveConfirmAlert = true }
                    } label: { Label(loc.leaveGroup, systemImage: "rectangle.portrait.and.arrow.right") }
                }
            } label: { Image(systemName: "gearshape") }
        }
    }

    // MARK: - Helpers

    func shareSummary() {
        var lines = ["💸 \(vm.group.name)"]
        lines.append("")
        lines.append(loc.totalSpent + ": \(CurrencySettings.shared.formatted(vm.totalSpent))")
        if !vm.debts.isEmpty {
            lines.append("")
            lines.append(loc.whoOwesWho + ":")
            for d in vm.debts {
                let from = vm.userNames[d.fromUserId] ?? "..."
                let to = vm.userNames[d.toUserId] ?? "..."
                lines.append("  \(from) → \(to): \(CurrencySettings.shared.formatted(d.amount))")
            }
        } else if !vm.bills.isEmpty {
            lines.append("")
            lines.append(loc.allSettled)
        }
        let text = lines.joined(separator: "\n")
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let vc = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController {
            vc.present(av, animated: true)
        }
    }

    func settle(_ debt: DebtEntry) {
        guard let groupId = vm.group.id, !settlingIds.contains(debt.id) else { return }
        settlingIds.insert(debt.id)
        Task {
            do {
                try await SettlementService.shared.createSettlement(groupId: groupId, fromUserId: debt.fromUserId, toUserId: debt.toUserId, amount: debt.amount)
                _ = await MainActor.run { toast = .success(loc.toastPaid) }
                await vm.reload()
            } catch {
                _ = await MainActor.run { toast = .error(error.localizedDescription) }
            }
            _ = await MainActor.run { settlingIds.remove(debt.id) }
        }
    }
    func confirmRemoveMember() {
        guard let memberId = removingMemberId, let groupId = vm.group.id else { return }
        Task {
            do {
                try await GroupService.shared.removeMember(groupId, userId: memberId)
                await vm.reload()
            } catch {
                _ = await MainActor.run { toast = .error(error.localizedDescription) }
            }
            _ = await MainActor.run { removingMemberId = nil }
        }
    }

    func confirmRevokeSettlement() {
        guard let sid = revokingSettlementId else { return }
        Task {
            do {
                try await SettlementService.shared.deleteSettlement(sid)
                await vm.reload()
                _ = await MainActor.run { toast = .info(loc.toastSettlementRevoked) }
            } catch {
                _ = await MainActor.run { toast = .error(error.localizedDescription) }
            }
            _ = await MainActor.run { revokingSettlementId = nil }
        }
    }

    func confirmDeleteBill() {
        guard let bill = deletingBill, let billId = bill.id else { return }
        _ = Task {
            do { try await BillService.shared.deleteBill(billId); await MainActor.run { toast = .success(loc.toastDeleted) }; await vm.reload() }
            catch { await MainActor.run { toast = .error(error.localizedDescription) } }
        }
    }
    func confirmDeleteGroup() {
        guard let groupId = vm.group.id else { return }
        _ = Task {
            do {
                try await GroupService.shared.deleteGroup(groupId)
                _ = await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("refreshGroups"), object: nil)
                    dismiss()
                }
            } catch {
                _ = await MainActor.run { toast = .error(error.localizedDescription) }
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
    @Binding var showLeaveConfirmAlert: Bool; @Binding var showLeaveAlert: Bool; @Binding var deletingBill: Bill?
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
            } message: { Text(loc.deleteBillMsg(vm.group.name)) }
            .alert(loc.cannotLeave, isPresented: $showLeaveAlert) {
                Button(loc.cancel, role: .cancel) {}
            } message: { Text(loc.cannotLeaveMsg) }
            .alert(loc.leaveGroup + "?", isPresented: $showLeaveConfirmAlert) {
                Button(loc.cancel, role: .cancel) {}
                Button(loc.leaveGroup, role: .destructive) { vm.leaveGroup(userId: authVM.currentUserId ?? "") }
            } message: { Text(loc.leaveConfirmMsg) }
    }
}
