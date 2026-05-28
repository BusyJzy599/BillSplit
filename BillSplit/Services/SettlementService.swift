import FirebaseFirestore

class SettlementService {
    static let shared = SettlementService()
    private let db = Firestore.firestore()

    func settlementsListener(for groupId: String, onUpdate: @escaping (QuerySnapshot?, Error?) -> Void) -> ListenerRegistration {
        return db.collection("settlements")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { snapshot, error in
                onUpdate(snapshot, error)
            }
    }

    func createSettlement(groupId: String, fromUserId: String, toUserId: String, amount: Double) async throws {
        let settlement = Settlement(
            billId: "",
            groupId: groupId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            amount: amount,
            status: .paid
        )
        _ = try db.collection("settlements").addDocument(from: settlement)
    }
}
