import FirebaseFirestore

class BillService {
    static let shared = BillService()
    private let db = Firestore.firestore()

    func billsListener(for groupId: String, onUpdate: @escaping (QuerySnapshot?, Error?) -> Void) -> ListenerRegistration {
        return db.collection("bills")
            .whereField("groupId", isEqualTo: groupId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                onUpdate(snapshot, error)
            }
    }

    func createBill(groupId: String, payerId: String, amount: Double,
                    description: String, participantIds: [String]) async throws {
        let bill = Bill(
            groupId: groupId,
            payerId: payerId,
            amount: amount,
            description: description,
            participantIds: participantIds,
            createdAt: Timestamp()
        )
        _ = try db.collection("bills").addDocument(from: bill)
    }
}
