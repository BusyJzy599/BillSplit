import Foundation

struct Bill: Codable, Identifiable {
    var id: Int?
    var groupId: Int
    var payerId: String
    var amount: Double
    var description: String
    var participantIds: [String]
    var createdAt: Date
}
