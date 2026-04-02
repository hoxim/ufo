import Foundation

struct SpaceMemberRecipient: Identifiable, Hashable {
    let id: UUID
    let email: String
    let fullName: String?
    let avatarURL: String?
    let providerAvatarURL: String?
    let role: String

    var displayName: String {
        if let fullName, !fullName.isEmpty { return fullName }
        return email
    }

    var effectiveAvatarURL: String? {
        if let avatarURL, !avatarURL.isEmpty {
            return avatarURL
        }
        if let providerAvatarURL, !providerAvatarURL.isEmpty {
            return providerAvatarURL
        }
        return nil
    }
}
