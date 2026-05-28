import FirebaseFirestore

struct Settlement: Codable, Identifiable {
    @DocumentID var id: String?
    var billId: String
    var groupId: String
    var fromUserId: String
    var toUserId: String
    var amount: Double
    var status: String // "pending" | "paid"
}
