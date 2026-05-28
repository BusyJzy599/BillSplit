import Foundation

enum SettlementStatus: String, Codable {
    case pending
    case paid
}

struct Settlement: Codable, Identifiable {
    var id: Int?
    var billId: Int?
    var groupId: Int
    var fromUserId: String
    var toUserId: String
    var amount: Double
    var status: SettlementStatus

    enum CodingKeys: String, CodingKey {
        case id
        case billId = "bill_id"
        case groupId = "group_id"
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case amount
        case status
    }
}
