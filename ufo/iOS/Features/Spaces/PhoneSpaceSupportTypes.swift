#if os(iOS)

import SwiftUI

enum PhoneSpaceFilter: String, CaseIterable, Identifiable {
    case all
    case shared
    case `private`

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return String(localized: "spaces.filter.all")
        case .shared:
            return String(localized: "spaces.filter.shared")
        case .private:
            return String(localized: "spaces.filter.private")
        }
    }
}

enum PhoneSpacePendingAction: Identifiable {
    case delete(Space, String)
    case leave(Space, String)

    var id: UUID {
        switch self {
        case .delete(let space, _), .leave(let space, _):
            return space.id
        }
    }

    var title: String {
        switch self {
        case .delete(let space, _):
            return String(format: String(localized: "spaces.pending.delete.title"), space.name)
        case .leave(let space, _):
            return String(format: String(localized: "spaces.pending.leave.title"), space.name)
        }
    }

    var message: String {
        switch self {
        case .delete:
            return String(localized: "spaces.pending.delete.message")
        case .leave:
            return String(localized: "spaces.pending.leave.message")
        }
    }

    var confirmTitle: String {
        switch self {
        case .delete:
            return String(localized: "spaces.pending.delete.confirm")
        case .leave:
            return String(localized: "spaces.pending.leave.confirm")
        }
    }
}

#endif
