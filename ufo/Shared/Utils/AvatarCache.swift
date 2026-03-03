import Foundation

final class AvatarCache {
    static let shared = AvatarCache()

    private let fileManager = FileManager.default
    private let folderURL: URL

    private init() {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        folderURL = base.appendingPathComponent("avatar-cache", isDirectory: true)
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    /// Handles local url.
    func localURL(userId: UUID, version: Int) -> URL {
        folderURL.appendingPathComponent("avatar_\(userId.uuidString)_v\(version).jpg")
    }

    /// Handles store.
    func store(_ data: Data, userId: UUID, version: Int) {
        let url = localURL(userId: userId, version: version)
        try? data.write(to: url, options: .atomic)
    }

    /// Handles existing url.
    func existingURL(userId: UUID, version: Int) -> URL? {
        let url = localURL(userId: userId, version: version)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
}
