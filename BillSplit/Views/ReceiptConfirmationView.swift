import SwiftUI

struct ReceiptConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    @State var items: [ReceiptItem]
    let groupId: Int
    let memberIds: [String]
    let userNames: [String: String]
    let currentUserId: String
    @State var payerId: String
    let onDismiss: () -> Void

    @State private var editingIndex: Int?
    @State private var showAddItem = false
    @State private var newDescription = ""
    @State private var newAmount = ""
    @State private var newIsShared = true
    @State private var newAssignedUserId: String?

    private var isEditing: Bool { editingIndex != nil }

    var body: some View {
        Form {
            Section("共享项目（均分给所有成员）") {
                let sharedItems = items.filter { $0.isShared }
                if sharedItems.isEmpty {
                    Text("无共享项目")
                        .foregroundColor(.secondary)
                }
                ForEach(sharedItems) { item in
                    itemRow(item)
                }
                .onDelete { indexSet in
                    let ids = indexSet.map { sharedItems[$0].id }
                    items.removeAll { ids.contains($0.id) }
                }
            }

            Section("个人项目") {
                let personalItems = items.filter { !$0.isShared }
                if personalItems.isEmpty {
                    Text("无个人项目")
                        .foregroundColor(.secondary)
                }
                ForEach(personalItems) { item in
                    itemRow(item)
                }
                .onDelete { indexSet in
                    let ids = indexSet.map { personalItems[$0].id }
                    items.removeAll { ids.contains($0.id) }
                }
            }

            Section {
                Button {
                    showAddItem = true
                    newDescription = ""
                    newAmount = ""
                    newIsShared = true
                    newAssignedUserId = nil
                } label: {
                    Label("添加项目", systemImage: "plus")
                }
            }

            Section("付款人") {
                Picker("付款人", selection: $payerId) {
                    ForEach(memberIds, id: \.self) { id in
                        Text(userNames[id] ?? "...").tag(id)
                    }
                }
            }

            if let err = submitError { Section { Text(err).foregroundColor(.red).font(.caption) } }

            Section {
                Button(isSubmitting ? "Creating..." : "Generate Bills") { submitBills() }
                    .disabled(items.isEmpty || isSubmitting)
            }
        }
        .navigationTitle("收据识别")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
        .sheet(isPresented: $showAddItem) {
            NavigationStack {
                Form {
                    TextField("描述", text: $newDescription)
                    TextField("金额", text: $newAmount)
                        .keyboardType(.decimalPad)
                    Toggle("共享项目", isOn: $newIsShared)
                    if !newIsShared {
                        Picker("属于谁", selection: Binding(
                            get: { newAssignedUserId ?? memberIds.first ?? "" },
                            set: { newAssignedUserId = $0 }
                        )) {
                            ForEach(memberIds, id: \.self) { id in
                                Text(userNames[id] ?? "...").tag(id)
                            }
                        }
                    }
                }
                .navigationTitle("添加项目")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { showAddItem = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("添加") {
                            let amount = Double(newAmount)
                            items.append(ReceiptItem(
                                description: newDescription,
                                amount: amount,
                                isShared: newIsShared,
                                assignedToUserId: newIsShared ? nil : newAssignedUserId
                            ))
                            showAddItem = false
                        }
                        .disabled(newDescription.isEmpty)
                    }
                }
            }
            .presentationDetents([.height(350)])
        }
        .sheet(isPresented: Binding(
            get: { editingIndex != nil },
            set: { if !$0 { editingIndex = nil } }
        )) {
            if let index = editingIndex, index < items.count {
                NavigationStack {
                    Form {
                        TextField("描述", text: $items[index].description)
                        TextField("金额", text: Binding(
                            get: {
                                if let a = items[index].amount { return String(format: "%.2f", a) }
                                return ""
                            },
                            set: { items[index].amount = Double($0) }
                        ))
                        .keyboardType(.decimalPad)
                        Toggle("共享项目", isOn: $items[index].isShared)
                        if !items[index].isShared {
                            Picker("属于谁", selection: Binding(
                                get: { items[index].assignedToUserId ?? memberIds.first ?? "" },
                                set: { items[index].assignedToUserId = $0 }
                            )) {
                                ForEach(memberIds, id: \.self) { id in
                                    Text(userNames[id] ?? "...").tag(id)
                                }
                            }
                        }
                    }
                    .navigationTitle("编辑项目")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { editingIndex = nil }
                        }
                    }
                }
                .presentationDetents([.height(350)])
            }
        }
    }

    @ViewBuilder
    private func itemRow(_ item: ReceiptItem) -> some View {
        HStack {
            Button {
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    withAnimation {
                        items[index].isShared.toggle()
                    }
                }
            } label: {
                Image(systemName: item.isShared ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isShared ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.description.isEmpty ? "未命名" : item.description)
                    .font(.subheadline)
                if let amount = item.amount {
                    Text(String(format: "¥%.2f", amount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !item.isShared, let userId = item.assignedToUserId {
                Text(userNames[userId] ?? "")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }

            Button {
                editingIndex = items.firstIndex(where: { $0.id == item.id })
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @State private var isSubmitting = false
    @State private var submitError: String?

    private func submitBills() {
        isSubmitting = true; submitError = nil
        let validItems = items.filter { ($0.amount ?? 0) > 0 }
        let sharedItems = validItems.filter { $0.isShared }
        let personalItems = validItems.filter { !$0.isShared }

        Task {
            do {
                if !sharedItems.isEmpty {
                    let totalShared = sharedItems.reduce(0.0) { $0 + ($1.amount ?? 0) }
                    let description = sharedItems.map { $0.description }.joined(separator: ", ")
                    try await BillService.shared.createBill(
                        groupId: groupId, payerId: payerId, amount: totalShared,
                        description: description, participantIds: memberIds)
                }

                for item in personalItems {
                    let userId = item.assignedToUserId ?? memberIds.first ?? ""
                    try await BillService.shared.createBill(
                        groupId: groupId, payerId: payerId, amount: item.amount ?? 0,
                        description: item.description, participantIds: [userId])
                }

                await MainActor.run { dismiss(); onDismiss() }
            } catch {
                await MainActor.run { submitError = error.localizedDescription; isSubmitting = false }
            }
        }
    }
}
