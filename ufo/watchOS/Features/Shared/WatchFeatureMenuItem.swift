#if os(watchOS)
import Foundation

enum WatchFeatureMenuItem: String, CaseIterable, Identifiable {
    case incidents
    case lists
    case missions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .incidents:
            return "Incidents"
        case .lists:
            return "Lists"
        case .missions:
            return "Missions"
        }
    }

    var systemImage: String {
        switch self {
        case .incidents:
            return "exclamationmark.triangle"
        case .lists:
            return "checklist"
        case .missions:
            return "flag"
        }
    }

    var subtitle: String {
        switch self {
        case .incidents:
            return "Zdarzenia i alerty"
        case .lists:
            return "Listy i pozycje"
        case .missions:
            return "Zadania do odczytu"
        }
    }
}

#endif
