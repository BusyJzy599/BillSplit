import Foundation

struct AppUser: Codable, Identifiable, Hashable {
    var id: String
    var displayName: String
    var email: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case createdAt = "created_at"
    }
}
