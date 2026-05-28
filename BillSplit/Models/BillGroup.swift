import Foundation

struct BillGroup: Codable, Identifiable, Hashable {
    var id: Int?
    var name: String
    var inviteCode: String
    var creatorId: String
    var memberIds: [String]
    var createdAt: Date
}
