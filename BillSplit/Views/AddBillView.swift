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
    @State private var selectedCategory: BillCategory = .other
    @FocusState private var isAmountFocused: Bool
    @State private var errorMessage: String?
    @StateObject private var loc = LocaleManager.shared
    @State private var isSubmitting = false

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
            let cur = Currency(rawValue: bill.currency) ?? .cny
            _currency = State(initialValue: cur)
            // For CNY: exchangeRate is 1.0 (amount already in CNY). For USD: stored rate.
            let rate = cur == .cny ? 1.0 : (bill.exchangeRate > 0 ? bill.exchangeRate : Currency.rateUSDToCNY)
            _exchangeRate = State(initialValue: rate)
            _description = State(initialValue: bill.description)
            _selectedCategory = State(initialValue: BillCategory(rawValue: bill.category) ?? .other)
            let original = rate > 0 ? bill.amount / rate : bill.amount
            _amountText = State(initialValue: String(format: "%.2f", original))
        } else {
            _selectedPayerId = State(initialValue: currentUserId)
            _selectedParticipantIds = State(initialValue: Set(memberIds))
            let cur = CurrencySettings.shared.current
            _currency = State(initialValue: cur)
            _exchangeRate = State(initialValue: cur == .cny ? 1.0 : Currency.rateUSDToCNY)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(loc.amount) {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .focused($isAmountFocused)
                }

                Section(loc.sectionCurrency) {
                    Picker(loc.sectionCurrency, selection: $currency) {
                        ForEach(Currency.allCases, id: \.rawValue) { c in
                            Text("\(c.symbol) \(c.name)").tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: currency) { _, new in
                        exchangeRate = new == .cny ? 1.0 : Currency.rateUSDToCNY
                    }

                    HStack {
                        Text(currency == .cny ? loc.storedAsCNY : "1 \(currency.symbol) = \(String(format: "%.4f", exchangeRate)) ¥")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if currency != .cny {
                            Text("→ \(String(format: "¥%.2f", (Double(amountText) ?? 0) * exchangeRate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(loc.description) {
                    TextField(loc.descriptionPlaceholder, text: $description)
                }

                Section(loc.sectionCategory) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 10) {
                        ForEach(BillCategory.allCases, id: \.self) { cat in
                            VStack(spacing: 4) {
                                Text(cat.icon).font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedCategory == cat ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                                    .cornerRadius(10)
                                Text(cat.displayName(loc.locale)).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                            }
                            .onTapGesture { selectedCategory = cat }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(loc.sectionPayer) {
                    Picker(loc.sectionPayer, selection: $selectedPayerId) {
                        ForEach(memberIds, id: \.self) { id in
                            Text(userNames[id] ?? "...").tag(id)
                        }
                    }
                }

                Section(loc.sectionParticipants) {
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

                if let error = errorMessage { Section { Text(error).foregroundColor(.red).font(.caption) } }

                Section {
                    Button(editBill != nil ? loc.updateBill : loc.submitBill) { submit() }
                        .disabled(isSubmitting || amountValue == nil || description.trimmingCharacters(in: .whitespaces).isEmpty || selectedParticipantIds.isEmpty)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(editBill != nil ? loc.editBill : loc.newBill)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(loc.cancel) { dismiss() } }
                ToolbarItem(placement: .keyboard) {
                    Button(loc.done) { isAmountFocused = false }
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
        isSubmitting = true; errorMessage = nil

        Task {
            do {
                if let bill = editBill, let billId = bill.id {
                    try await BillService.shared.updateBill(
                        id: billId, amount: amountInCNY, description: description,
                        participantIds: Array(selectedParticipantIds), currency: currency.rawValue, exchangeRate: exchangeRate,
                        category: selectedCategory.rawValue)
                } else {
                    try await BillService.shared.createBill(
                        groupId: groupId, payerId: selectedPayerId, amount: amountInCNY,
                        description: description, participantIds: Array(selectedParticipantIds),
                        currency: currency.rawValue, exchangeRate: exchangeRate,
                        category: selectedCategory.rawValue)
                }
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("refreshGroups"), object: nil)
                    dismiss()
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isSubmitting = false }
            }
        }
    }
}
