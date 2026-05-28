import Foundation
import Supabase

class BillService {
    static let shared = BillService()

    func getBills(for groupId: Int) async throws -> [Bill] {
        let bills: [Bill] = try await supabase.from("bills").select().eq("groupId", value: groupId).order("createdAt", ascending: false).execute().value
        return bills
    }

    func createBill(groupId: Int, payerId: String, amount: Double,
                    description: String, participantIds: [String]) async throws {
        let bill = Bill(
            groupId: groupId,
            payerId: payerId,
            amount: amount,
            description: description,
            participantIds: participantIds,
            createdAt: Date()
        )
        try await supabase.from("bills").insert(bill).execute()
    }
}
