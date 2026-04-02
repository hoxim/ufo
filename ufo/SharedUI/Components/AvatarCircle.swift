import SwiftUI

struct AvatarCircle: View {
    let user: UserProfile?
    var size: CGFloat = 36

    var body: some View {
        Group {
            if let user, let localURL = AvatarCache.shared.existingURL(userId: user.id, version: user.avatarVersion) {
                AsyncImage(url: localURL) { phase in
                    if case .success(let image) = phase {
                        avatarImage(from: image)
                    } else {
                        fallbackAvatar
                    }
                }
            } else if let urlString = user?.effectiveAvatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        avatarImage(from: image)
                    } else {
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(Color.accentColor.gradient)
            .frame(width: size, height: size)
            .overlay {
                Text(user?.effectiveDisplayName?.prefix(1) ?? "U")
                    .foregroundStyle(.white)
                    .font(.system(size: max(size * 0.42, 11), weight: .bold))
            }
    }

    private func avatarImage(from image: Image) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipped()
    }
}
