import FirebaseFirestore

struct BillGroup: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var inviteCode: String
    var creatorId: String
    var memberIds: [String]
    var createdAt: Timestamp
}
