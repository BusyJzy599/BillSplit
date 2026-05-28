import Foundation

struct DebtEntry: Identifiable {
    let id = UUID()
    let fromUserId: String
    let toUserId: String
    let amount: Double
}

class DebtCalculator {
    static func compute(bills: [Bill], settlements: [Settlement]) -> [DebtEntry] {
        // net[userId] = positive means owed money (creditor), negative means owes money (debtor)
        var net: [String: Double] = [:]

        for bill in bills {
            let share = bill.amount / Double(bill.participantIds.count)
            net[bill.payerId, default: 0] += bill.amount
            for pid in bill.participantIds {
                net[pid, default: 0] -= share
            }
        }

        for s in settlements where s.status == .paid {
            net[s.fromUserId, default: 0] += s.amount  // debtor pays → net improves
            net[s.toUserId, default: 0] -= s.amount    // creditor receives → net decreases
        }

        let creditors = net.filter { $0.value > 0.01 }.sorted { $0.value > $1.value }
        let debtors = net.filter { $0.value < -0.01 }.sorted { $0.value < $1.value }

        var result: [DebtEntry] = []
        var i = 0, j = 0
        var netCopy = net

        while i < creditors.count && j < debtors.count {
            let owed = creditors[i].value
            let debt = -debtors[j].value
            let amount = min(owed, debt)

            result.append(DebtEntry(fromUserId: debtors[j].key, toUserId: creditors[i].key, amount: amount))

            netCopy[creditors[i].key]! -= amount
            netCopy[debtors[j].key]! += amount

            if netCopy[creditors[i].key]! < 0.01 { i += 1 }
            if netCopy[debtors[j].key]! > -0.01 { j += 1 }
        }
        return result
    }
}
