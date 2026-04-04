#if os(watchOS)
import Foundation

enum WatchFeatureMenuItem: String, CaseIterable, Identifiable {
    case notes
    case routines
    case locations
    case people
    case notifications
    case incidents
    case lists
    case missions

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .notes:
            return "watch.feature.notes.title"
        case .routines:
            return "watch.feature.routines.title"
        case .locations:
            return "watch.feature.locations.title"
        case .people:
            return "watch.feature.people.title"
        case .notifications:
            return "watch.feature.notifications.title"
        case .incidents:
            return "watch.feature.incidents.title"
        case .lists:
            return "watch.feature.lists.title"
        case .missions:
            return "watch.feature.missions.title"
        }
    }

    var systemImage: String {
        switch self {
        case .notes:
            return "note.text"
        case .routines:
            return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .locations:
            return "mappin.and.ellipse"
        case .people:
            return "person.2"
        case .notifications:
            return "bell.badge"
        case .incidents:
            return "exclamationmark.triangle"
        case .lists:
            return "checklist"
        case .missions:
            return "flag"
        }
    }

    var subtitleKey: String {
        switch self {
        case .notes:
            return "watch.feature.notes.subtitle"
        case .routines:
            return "watch.feature.routines.subtitle"
        case .locations:
            return "watch.feature.locations.subtitle"
        case .people:
            return "watch.feature.people.subtitle"
        case .notifications:
            return "watch.feature.notifications.subtitle"
        case .incidents:
            return "watch.feature.incidents.subtitle"
        case .lists:
            return "watch.feature.lists.subtitle"
        case .missions:
            return "watch.feature.missions.subtitle"
        }
    }
}

#endif
