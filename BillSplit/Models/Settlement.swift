import FirebaseFirestore

enum SettlementStatus: String, Codable {
    case pending
    case paid
}

struct Settlement: Codable, Identifiable {
    @DocumentID var id: String?
    var billId: String
    var groupId: String
    var fromUserId: String
    var toUserId: String
    var amount: Double
    var status: SettlementStatus
}
