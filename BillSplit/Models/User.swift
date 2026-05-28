import Foundation

struct AppUser: Codable, Identifiable, Hashable {
    var id: String
    var displayName: String
    var email: String
    var avatarUrl: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}
