import Foundation
import Supabase

class SettlementService {
    static let shared = SettlementService()

    func getSettlements(for groupId: Int) async throws -> [Settlement] {
        let settlements: [Settlement] = try await supabase.from("settlements").select().eq("group_id", value: groupId).execute().value
        return settlements
    }

    func createSettlement(groupId: Int, fromUserId: String, toUserId: String, amount: Double) async throws {
        let settlement = Settlement(groupId: groupId, fromUserId: fromUserId, toUserId: toUserId, amount: amount, status: .paid)
        try await supabase.from("settlements").insert(settlement).execute()
    }

    func deleteSettlement(_ settlementId: Int) async throws {
        try await supabase.from("settlements").delete().eq("id", value: settlementId).execute()
    }
}
