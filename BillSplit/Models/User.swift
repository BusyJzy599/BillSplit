import Foundation

struct AppUser: Codable, Identifiable, Hashable {
    var id: String
    var displayName: String
    var email: String
    var createdAt: Date
}
