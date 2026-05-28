import SwiftUI

struct AddBillView: View {
    @Environment(\.dismiss) var dismiss
    let groupId: Int
    let memberIds: [String]
    let userNames: [String: String]
    let currentUserId: String

    // Edit mode: if editing, pass the bill to edit
    var editBill: Bill? = nil

    @State private var amountText = ""
    @State private var description = ""
    @State private var selectedPayerId: String
    @State private var selectedParticipantIds: Set<String>
    @State private var currency: Currency = CurrencySettings.shared.current
    @State private var exchangeRate: Double = Currency.rateUSDToCNY
    @FocusState private var isAmountFocused: Bool

    init(groupId: Int, memberIds: [String], userNames: [String: String], currentUserId: String, editBill: Bill? = nil) {
        self.groupId = groupId
        self.memberIds = memberIds
        self.userNames = userNames
        self.currentUserId = currentUserId
        self.editBill = editBill

        // Pre-fill for edit mode
        if let bill = editBill {
            _selectedPayerId = State(initialValue: bill.payerId)
            _selectedParticipantIds = State(initialValue: Set(bill.participantIds))
            _currency = State(initialValue: Currency(rawValue: bill.currency) ?? .cny)
            _exchangeRate = State(initialValue: bill.exchangeRate)
            _description = State(initialValue: bill.description)
            // Reverse-convert from CNY to input currency amount
            let original = bill.exchangeRate > 0 ? bill.amount / bill.exchangeRate : bill.amount
            _amountText = State(initialValue: String(format: "%.2f", original))
        } else {
            _selectedPayerId = State(initialValue: currentUserId)
            _selectedParticipantIds = State(initialValue: Set(memberIds))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("金额") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .focused($isAmountFocused)
                }

                Section("币种") {
                    Picker("币种", selection: $currency) {
                        ForEach(Currency.allCases, id: \.rawValue) { c in
                            Text("\(c.symbol) \(c.name)").tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: currency) { _, _ in
                        exchangeRate = Currency.rateUSDToCNY
                    }

                    HStack {
                        Text("汇率 (→ CNY)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "1 \(currency.symbol) = %.4f ¥", exchangeRate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                    Button(editBill != nil ? "更新账单" : "提交账单") {
                        submit()
                    }
                    .disabled(amountValue == nil || description.trimmingCharacters(in: .whitespaces).isEmpty || selectedParticipantIds.isEmpty)
                }
            }
            .navigationTitle(editBill != nil ? "编辑账单" : "新建账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { isAmountFocused = false }
                }
            }
        }
    }

    private var amountValue: Double? {
        Double(amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    private func submit() {
        guard let inputAmount = amountValue else { return }
        let amountInCNY = currency.convert(inputAmount, to: .cny)

        Task {
            if let bill = editBill, let billId = bill.id {
                try? await BillService.shared.updateBill(
                    id: billId,
                    amount: amountInCNY,
                    description: description,
                    participantIds: Array(selectedParticipantIds),
                    currency: currency.rawValue,
                    exchangeRate: exchangeRate
                )
            } else {
                try? await BillService.shared.createBill(
                    groupId: groupId,
                    payerId: selectedPayerId,
                    amount: amountInCNY,
                    description: description,
                    participantIds: Array(selectedParticipantIds),
                    currency: currency.rawValue,
                    exchangeRate: exchangeRate
                )
            }
            await MainActor.run { dismiss() }
        }
    }
}
