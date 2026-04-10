#if os(iOS)

import SwiftUI
import Charts


struct PadNotificationBellButton: View {
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: unreadCount > 0 ? "bell.fill" : "bell")
                .font(.headline.weight(.semibold))
                .foregroundStyle(unreadCount > 0 ? Color.accentColor : .primary)

            if unreadCount > 0 {
                Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.Colors.mutedFill)
                    )
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
    }
}

struct PadHomeWidgetRow: Identifiable {
    enum Style {
        case single
        case pair
    }

    let style: Style
    let widgets: [HomeWidgetPreference]

    var id: String {
        widgets.map(\.kind.rawValue).joined(separator: "_")
    }
}

struct PadHomeMetricCardPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.clear)
            .frame(maxWidth: .infinity, minHeight: 136, maxHeight: 136, alignment: .leading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct PadActiveSpaceMenuButton: View {
    let space: Space

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AppTheme.Colors.mutedFill)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: "person.3.fill")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.FeatureColors.spacesAccent)
                }

            Text(space.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum PadHomeRoute: Hashable, Identifiable {
    case missions
    case lists
    case notes
    case incidents
    case notifications
    case locations
    case routines
    case budget
    case quickAddMission
    case quickAddNote
    case quickAddIncident
    case quickAddList
    case quickAddBudgetEntry

    var id: String {
        switch self {
        case .missions: "missions"
        case .lists: "lists"
        case .notes: "notes"
        case .incidents: "incidents"
        case .notifications: "notifications"
        case .locations: "locations"
        case .routines: "routines"
        case .budget: "budget"
        case .quickAddMission: "quickAddMission"
        case .quickAddNote: "quickAddNote"
        case .quickAddIncident: "quickAddIncident"
        case .quickAddList: "quickAddList"
        case .quickAddBudgetEntry: "quickAddBudgetEntry"
        }
    }
}

enum PadBudgetWidgetRange: CaseIterable {
    case today
    case week
    case month

    var title: String {
        switch self {
        case .today: String(localized: "home.range.today")
        case .week: String(localized: "home.range.week")
        case .month: String(localized: "home.range.month")
        }
    }

    var days: Int {
        switch self {
        case .today: 1
        case .week: 7
        case .month: 30
        }
    }
}

struct PadHomeWidgetState {
    var nextMissionTitle: String?
    var activeListsCount: Int = 0
    var notesCount: Int = 0
    var nearestIncidentTitle: String?
    var nearestIncidentDateText: String?
    var dueTodayCount: Int = 0
    var recurringMissionCount: Int = 0
    var pinnedNotesCount: Int = 0
    var openIncidentsCount: Int = 0
    var criticalIncidentsCount: Int = 0
    var savedPlacesCount: Int = 0
    var recentCheckInText: String?
    var routinesCount: Int = 0
    var completedTodayRoutinesCount: Int = 0
    var nextRoutineText: String?
    var budgetEntries: [BudgetEntry] = []

    var routinesProgressText: String {
        guard routinesCount > 0 else { return "0" }
        return "\(completedTodayRoutinesCount)/\(routinesCount)"
    }
}

#Preview("iPad Notification Bell") {
    VStack(spacing: 16) {
        PadNotificationBellButton(unreadCount: 0)
        PadNotificationBellButton(unreadCount: 12)
    }
    .padding()
    .background(AppTheme.Colors.canvas)
}

#Preview("iPad Active Space Button") {
    PadActiveSpaceMenuButton(
        space: Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    )
    .padding()
    .background(AppTheme.Colors.canvas)
}


#endif
