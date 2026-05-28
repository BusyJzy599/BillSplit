import SwiftUI

struct AddBillView: View {
    @Environment(\.dismiss) var dismiss
    let groupId: Int
    let memberIds: [String]
    let userNames: [String: String]
    let currentUserId: String

    @State private var amountText = ""
    @State private var description = ""
    @State private var selectedPayerId: String
    @State private var selectedParticipantIds: Set<String>

    init(groupId: Int, memberIds: [String], userNames: [String: String], currentUserId: String) {
        self.groupId = groupId
        self.memberIds = memberIds
        self.userNames = userNames
        self.currentUserId = currentUserId
        _selectedPayerId = State(initialValue: currentUserId)
        _selectedParticipantIds = State(initialValue: Set(memberIds))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("金额") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                }

                Section("描述") {
                    TextField("例如: 晚餐", text: $description)
                }

                Section("付款人") {
                    Picker("付款人", selection: $selectedPayerId) {
                        ForEach(memberIds, id: \.self) { id in
                            Text(userNames[id] ?? "...").tag(id)
                        }
                    }
                }

                Section("参与人") {
                    ForEach(memberIds, id: \.self) { id in
                        HStack {
                            Text(userNames[id] ?? "...")
                            Spacer()
                            if selectedParticipantIds.contains(id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedParticipantIds.contains(id) {
                                if selectedParticipantIds.count > 1 {
                                    selectedParticipantIds.remove(id)
                                }
                            } else {
                                selectedParticipantIds.insert(id)
                            }
                        }
                    }
                }

                Section {
                    Button("提交账单") {
                        submit()
                    }
                    .disabled(amountValue == nil || description.trimmingCharacters(in: .whitespaces).isEmpty || selectedParticipantIds.isEmpty)
                }
            }
            .navigationTitle("新建账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }

    private var amountValue: Double? {
        Double(amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    private func submit() {
        guard let amount = amountValue else { return }
        Task {
            try? await BillService.shared.createBill(
                groupId: groupId,
                payerId: selectedPayerId,
                amount: amount,
                description: description,
                participantIds: Array(selectedParticipantIds)
            )
            await MainActor.run { dismiss() }
        }
    }
}
