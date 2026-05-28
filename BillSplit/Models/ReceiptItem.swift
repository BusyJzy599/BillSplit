import Foundation

struct ReceiptItem: Identifiable, Codable {
    var id = UUID()
    var description: String
    var amount: Double?
    var isShared: Bool = true
    var assignedToUserId: String?
}
