import FirebaseFirestore

struct Bill: Codable, Identifiable {
    @DocumentID var id: String?
    var groupId: String
    var payerId: String
    var amount: Double
    var description: String
    var participantIds: [String]
    var createdAt: Timestamp
}
