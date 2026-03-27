import SwiftUI
import Charts

struct NotificationBellButton: View {
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

struct HomeWidgetRow: Identifiable {
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

struct HomeMetricCardPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.clear)
            .frame(maxWidth: .infinity, minHeight: 136, maxHeight: 136, alignment: .leading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct ActiveSpaceMenuButton: View {
    let space: Space

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(space.type == .personal || space.type == .private ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: "person.3.fill")
                        .font(.caption.bold())
                        .foregroundStyle(space.type == .personal || space.type == .private ? .orange : .blue)
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

enum HomeRoute: Hashable, Identifiable {
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

enum BudgetWidgetRange: CaseIterable {
    case today
    case week
    case month

    var title: String {
        switch self {
        case .today: "Today"
        case .week: "Week"
        case .month: "Month"
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

struct HomeWidgetState {
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

struct TodaySummaryCard: View {
    let widget: HomeWidgetState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeWidgetSectionHeader(
                title: "Family Hub",
                icon: "person.3.sequence.fill"
            )

            Text("Quick snapshot of today across missions, notes, incidents and saved places.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                summaryPill(title: "Due missions", value: "\(widget.dueTodayCount)", tint: .orange)
                summaryPill(title: "Recurring", value: "\(widget.recurringMissionCount)", tint: .blue)
                summaryPill(title: "Pinned notes", value: "\(widget.pinnedNotesCount)", tint: .pink)
            }

            HStack(spacing: 12) {
                summaryPill(title: "Open incidents", value: "\(widget.openIncidentsCount)", tint: .red)
                summaryPill(title: "Critical alerts", value: "\(widget.criticalIncidentsCount)", tint: .red.opacity(0.8))
                summaryPill(title: "Saved places", value: "\(widget.savedPlacesCount)", tint: .green)
            }

            if let recentCheckInText = widget.recentCheckInText {
                Label("Last check-in: \(recentCheckInText)", systemImage: "location.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No recent check-ins")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func summaryPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct HomeBudgetCard: View {
    let entries: [BudgetEntry]
    @Binding var range: BudgetWidgetRange
    let onOpen: () -> Void

    private var filteredEntries: [BudgetEntry] {
        let start = Calendar.current.date(byAdding: .day, value: -(range.days - 1), to: Date()) ?? Date()
        return entries.filter { $0.entryDate >= start }
    }

    private var balance: Double {
        filteredEntries.reduce(0) { partial, entry in
            partial + (entry.kind == BudgetEntryKind.expense.rawValue ? -entry.amount : entry.amount)
        }
    }

    private var income: Double {
        filteredEntries
            .filter { $0.kind == BudgetEntryKind.income.rawValue }
            .reduce(0) { $0 + $1.amount }
    }

    private var expense: Double {
        filteredEntries
            .filter { $0.kind == BudgetEntryKind.expense.rawValue }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeWidgetSectionHeader(
                title: "Budget",
                icon: "dollarsign.circle",
                onOpen: onOpen
            )

            HStack(spacing: 8) {
                ForEach(BudgetWidgetRange.allCases, id: \.self) { option in
                    Button {
                        range = option
                    } label: {
                        Text(option.title)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(range == option ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(balance.formatted(.currency(code: "PLN")))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(balance >= 0 ? .green : .red)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(income.formatted(.currency(code: "PLN")))
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Expense")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(expense.formatted(.currency(code: "PLN")))
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            if filteredEntries.isEmpty {
                Text("No entries in selected period")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(filteredEntries.suffix(10)) { entry in
                    BarMark(
                        x: .value("Date", entry.entryDate, unit: .day),
                        y: .value("Amount", entry.kind == BudgetEntryKind.expense.rawValue ? -entry.amount : entry.amount)
                    )
                    .foregroundStyle(entry.kind == BudgetEntryKind.expense.rawValue ? .red : .green)
                }
                .frame(height: 140)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            onOpen()
        }
    }
}

struct HomeWidgetSectionHeader: View {
    let title: String
    let icon: String
    var onOpen: (() -> Void)? = nil

    private var sectionForeground: Color {
        Color.primary.opacity(0.92)
    }

    private var chevronForeground: Color {
        Color.primary.opacity(0.72)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(sectionForeground)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(sectionForeground)

            Spacer()

            if let onOpen {
                Button(action: onOpen) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(chevronForeground)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct HomeMetricCard: View {
    let sectionTitle: String
    let sectionIcon: String
    let title: String
    let value: String
    let subtitle: String
    let tint: Color
    let span: HomeWidgetSpan

    private var sectionForeground: Color {
        Color.primary.opacity(0.92)
    }

    private var chevronForeground: Color {
        Color.primary.opacity(0.72)
    }

    private var cardHeight: CGFloat {
        span == .full ? 112 : 136
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: sectionIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(sectionForeground)

                Text(sectionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(sectionForeground)

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(chevronForeground)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct HomeCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        @Bindable var appPreferences = appPreferences

        NavigationStack {
            List {
                Section {
                    Text("Dodaj, ukryj i ustaw kolejność widgetów ekranu głównego. Przeciągnij uchwyt po prawej, żeby zmienić kolejność.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Widgets") {
                    ForEach($appPreferences.homeWidgets) { $preference in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Label(preference.kind.title, systemImage: preference.kind.systemImage)
                                    .font(.body.weight(.semibold))

                                Spacer()

                                Button {
                                    preference.isVisible.toggle()
                                } label: {
                                    Image(systemName: preference.isVisible ? "minus.circle.fill" : "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(preference.isVisible ? .red : .green)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(preference.isVisible ? "Hide widget" : "Show widget")
                            }

                            if preference.kind.supportedSpans.count > 1 {
                                Picker("Size", selection: $preference.span) {
                                    ForEach(preference.kind.supportedSpans) { span in
                                        Text(span.title).tag(span)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { fromOffsets, toOffset in
                        appPreferences.homeWidgets.move(fromOffsets: fromOffsets, toOffset: toOffset)
                    }
                }
            }
            #if os(iOS)
            .environment(\.editMode, .constant(.active))
            #endif
            .navigationTitle("Customize Home")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

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
