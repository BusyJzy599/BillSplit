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
}
