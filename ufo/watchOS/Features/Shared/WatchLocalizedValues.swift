#if os(watchOS)
import Foundation

func watchLocalizedMissionPriority(_ rawValue: String) -> String {
    switch rawValue {
    case "low":
        return String(localized: "watch.common.priority.low")
    case "medium":
        return String(localized: "watch.common.priority.medium")
    case "high":
        return String(localized: "watch.common.priority.high")
    default:
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

func watchLocalizedIncidentSeverity(_ rawValue: String) -> String {
    switch rawValue {
    case "low":
        return String(localized: "watch.common.priority.low")
    case "medium":
        return String(localized: "watch.common.priority.medium")
    case "high":
        return String(localized: "watch.common.priority.high")
    case "critical":
        return String(localized: "watch.common.priority.critical")
    default:
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

func watchLocalizedIncidentStatus(_ rawValue: String) -> String {
    switch rawValue {
    case "open":
        return String(localized: "watch.common.status.open")
    case "in_progress":
        return String(localized: "watch.common.status.inProgress")
    case "resolved":
        return String(localized: "watch.common.status.resolved")
    default:
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

func watchLocalizedListType(_ rawValue: String) -> String {
    switch rawValue {
    case "shopping":
        return String(localized: "watch.lists.type.shopping")
    case "goals":
        return String(localized: "watch.lists.type.goals")
    default:
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

func watchLocalizedPlaceCategory(_ rawValue: String) -> String {
    switch rawValue {
    case "home":
        return String(localized: "watch.locations.category.home")
    case "school":
        return String(localized: "watch.locations.category.school")
    case "work":
        return String(localized: "watch.locations.category.work")
    case "doctor":
        return String(localized: "watch.locations.category.doctor")
    case "activity":
        return String(localized: "watch.locations.category.activity")
    case "other":
        return String(localized: "watch.locations.category.other")
    default:
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

func watchLocalizedSpaceRole(_ rawValue: String) -> String {
    switch rawValue {
    case "admin":
        return String(localized: "watch.people.role.admin")
    case "member":
        return String(localized: "watch.people.role.member")
    case "parent":
        return String(localized: "watch.people.role.parent")
    case "child":
        return String(localized: "watch.people.role.child")
    case "contributor":
        return String(localized: "watch.people.role.contributor")
    case "viewer":
        return String(localized: "watch.people.role.viewer")
    default:
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

#endif
