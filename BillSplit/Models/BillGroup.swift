import Foundation

struct BillGroup: Codable, Identifiable, Hashable {
    var id: Int?
    var name: String
    var inviteCode: String
    var creatorId: String
    var memberIds: [String]
    var icon: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case inviteCode = "invite_code"
        case creatorId = "creator_id"
        case memberIds = "member_ids"
        case icon
        case createdAt = "created_at"
    }
}
