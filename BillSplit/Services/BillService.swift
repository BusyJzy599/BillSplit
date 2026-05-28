import Foundation
import Supabase

class BillService {
    static let shared = BillService()

    func getBills(for groupId: Int) async throws -> [Bill] {
        let bills: [Bill] = try await supabase.from("bills").select().eq("group_id", value: groupId).order("created_at", ascending: false).execute().value
        return bills
    }

    func createBill(groupId: Int, payerId: String, amount: Double,
                    description: String, participantIds: [String],
                    currency: String = "cny", exchangeRate: Double = 1.0) async throws {
        let bill = Bill(
            groupId: groupId,
            payerId: payerId,
            amount: amount,
            description: description,
            participantIds: participantIds,
            currency: currency,
            exchangeRate: exchangeRate,
            createdAt: Date()
        )
        try await supabase.from("bills").insert(bill).execute()
    }

    func updateBill(id: Int, amount: Double, description: String, participantIds: [String],
                    currency: String, exchangeRate: Double) async throws {
        struct UpdatePayload: Encodable {
            let amount: Double
            let description: String
            let participant_ids: [String]
            let currency: String
            let exchange_rate: Double
        }
        try await supabase.from("bills")
            .update(UpdatePayload(
                amount: amount,
                description: description,
                participant_ids: participantIds,
                currency: currency,
                exchange_rate: exchangeRate
            ))
            .eq("id", value: id)
            .execute()
    }

    func deleteBill(_ billId: Int) async throws {
        try await supabase.from("bills").delete().eq("id", value: billId).execute()
    }
}
