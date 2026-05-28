import Foundation

struct Bill: Codable, Identifiable {
    var id: Int?
    var groupId: Int
    var payerId: String
    var amount: Double
    var description: String
    var participantIds: [String]
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case payerId = "payer_id"
        case amount
        case description
        case participantIds = "participant_ids"
        case createdAt = "created_at"
    }
}
