import Foundation

struct SpaceMemberUserDTO: Codable {
    let id: UUID
    let email: String?
    let fullName: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }
}
