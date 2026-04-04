import Foundation
import SwiftData

@Model
final class AppNotification {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID?
    var title: String
    var body: String
    var categoryRaw: String
    var priorityRaw: String
    var createdAt: Date
    var scheduledAt: Date?
    var readAt: Date?
    var deepLink: String?
    var source: String?

    init(
        id: UUID = UUID(),
        spaceId: UUID? = nil,
        title: String,
        body: String,
        category: AppNotificationCategory,
        priority: AppNotificationPriority,
        createdAt: Date = .now,
        scheduledAt: Date? = nil,
        readAt: Date? = nil,
        deepLink: String? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.title = title
        self.body = body
        self.categoryRaw = category.rawValue
        self.priorityRaw = priority.rawValue
        self.createdAt = createdAt
        self.scheduledAt = scheduledAt
        self.readAt = readAt
        self.deepLink = deepLink
        self.source = source
    }
}

extension AppNotification {
    var category: AppNotificationCategory {
        AppNotificationCategory(rawValue: categoryRaw) ?? .system
    }

    var priority: AppNotificationPriority {
        AppNotificationPriority(rawValue: priorityRaw) ?? .normal
    }

    var isRead: Bool {
        readAt != nil
    }
}

enum AppNotificationCategory: String, CaseIterable, Identifiable {
    case system
    case info
    case alert
    case actionRequired
    case critical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return String(localized: "notifications.category.system")
        case .info:
            return String(localized: "notifications.category.info")
        case .alert:
            return String(localized: "notifications.category.alert")
        case .actionRequired:
            return String(localized: "notifications.category.actionRequired")
        case .critical:
            return String(localized: "notifications.category.critical")
        }
    }

    var symbolName: String {
        switch self {
        case .system:
            return "gearshape.2"
        case .info:
            return "info.circle"
        case .alert:
            return "bell.badge"
        case .actionRequired:
            return "checkmark.circle"
        case .critical:
            return "exclamationmark.triangle"
        }
    }
}

enum AppNotificationPriority: String, CaseIterable, Identifiable {
    case passive
    case normal
    case important
    case critical

    var id: String { rawValue }
}

enum AppToastStyle: String {
    case success
    case info
    case warning
    case error

    var symbolName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }
}

struct AppToast: Identifiable, Equatable {
    let id: UUID = UUID()
    let title: String
    let message: String?
    let style: AppToastStyle
}
