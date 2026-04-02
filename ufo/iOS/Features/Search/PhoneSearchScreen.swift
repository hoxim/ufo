#if os(iOS)

import SwiftUI
import SwiftData

struct PhoneSearchScreen: View {
    @Environment(\.selectedSpaceID) private var selectedSpaceID

    @Query(sort: \Mission.updatedAt, order: .reverse) private var missions: [Mission]
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Query(sort: \SharedList.updatedAt, order: .reverse) private var lists: [SharedList]
    @Query(sort: \Incident.updatedAt, order: .reverse) private var incidents: [Incident]
    @Query(sort: \SavedPlace.updatedAt, order: .reverse) private var places: [SavedPlace]

    @State private var query = ""
    @State private var selectedScope: SearchScope = .all
    @State private var selectedRoute: RelatedContentRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                searchHeader
                scopePicker

                if normalizedQuery.isEmpty {
                    searchStartState
                } else if resultSections.isEmpty {
                    ContentUnavailableView(
                        "Brak wyników",
                        systemImage: "magnifyingglass",
                        description: Text("Nie znaleziono nic dla „\(query)”. Spróbuj innego słowa albo zmień filtr.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(resultSections) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(section.title)
                                        .font(.headline)

                                    Spacer()

                                    Text("\(section.results.count)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(AppTheme.Colors.mutedFill, in: Capsule())
                                }

                                VStack(spacing: 10) {
                                    ForEach(section.results) { result in
                                        RelatedContentButton(
                                            title: result.title,
                                            subtitle: result.subtitle,
                                            systemImage: result.systemImage,
                                            tint: result.tint
                                        ) {
                                            selectedRoute = result.route
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 920, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .appScreenBackground()
        .navigationTitle("Szukaj")
        .inlineNavigationTitle()
        .searchable(text: $query, placement: .automatic, prompt: "Szukaj w notatkach, misjach, listach i miejscach")
        .navigationDestination(item: $selectedRoute) { route in
            RelatedContentDestinationView(route: route, originLabel: "Wyniki wyszukiwania")
        }
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visibleMissions: [Mission] {
        guard let selectedSpaceID else { return [] }
        return missions.filter { $0.spaceId == selectedSpaceID && $0.deletedAt == nil }
    }

    private var visibleNotes: [Note] {
        guard let selectedSpaceID else { return [] }
        return notes.filter { $0.spaceId == selectedSpaceID && $0.deletedAt == nil }
    }

    private var visibleLists: [SharedList] {
        guard let selectedSpaceID else { return [] }
        return lists.filter { $0.spaceId == selectedSpaceID && $0.deletedAt == nil }
    }

    private var visibleIncidents: [Incident] {
        guard let selectedSpaceID else { return [] }
        return incidents.filter { $0.spaceId == selectedSpaceID && $0.deletedAt == nil }
    }

    private var visiblePlaces: [SavedPlace] {
        guard let selectedSpaceID else { return [] }
        return places.filter { $0.spaceId == selectedSpaceID && $0.deletedAt == nil }
    }

    private var filteredMissions: [SearchResultItem] {
        visibleMissions
            .filter {
                matches($0.title)
                    || matches($0.missionDescription)
                    || matches($0.savedPlaceName)
            }
            .prefix(8)
            .map {
                SearchResultItem(
                    route: .mission($0.id),
                    title: $0.title,
                    subtitle: subtitle(primary: $0.missionDescription, fallback: $0.savedPlaceName),
                    systemImage: $0.iconName ?? "flag",
                    tint: Color(hex: $0.iconColorHex ?? "#F59E0B")
                )
            }
    }

    private var filteredNotes: [SearchResultItem] {
        visibleNotes
            .filter {
                matches($0.title)
                    || matches($0.previewText)
                    || $0.resolvedTags.contains(where: matches)
            }
            .prefix(8)
            .map {
                SearchResultItem(
                    route: .note($0.id),
                    title: $0.title.isEmpty ? "Bez tytułu" : $0.title,
                    subtitle: subtitle(primary: $0.previewText, fallback: nil),
                    systemImage: "note.text",
                    tint: .blue
                )
            }
    }

    private var filteredLists: [SearchResultItem] {
        visibleLists
            .filter {
                matches($0.name)
                    || matches($0.savedPlaceName)
                    || $0.items.contains(where: { item in
                        item.deletedAt == nil && matches(item.title)
                    })
            }
            .prefix(8)
            .map {
                let matchedItem = $0.items.first(where: { item in
                    item.deletedAt == nil && matches(item.title)
                })?.title

                return SearchResultItem(
                    route: .list($0.id),
                    title: $0.name,
                    subtitle: subtitle(
                        primary: matchedItem.map { "Element: \($0)" },
                        fallback: $0.savedPlaceName
                    ),
                    systemImage: $0.iconName ?? "checklist",
                    tint: Color(hex: $0.iconColorHex ?? "#EC4899")
                )
            }
    }

    private var filteredIncidents: [SearchResultItem] {
        visibleIncidents
            .filter {
                matches($0.title)
                    || matches($0.incidentDescription)
            }
            .prefix(8)
            .map {
                SearchResultItem(
                    route: .incident($0.id),
                    title: $0.title,
                    subtitle: subtitle(primary: $0.incidentDescription, fallback: nil),
                    systemImage: $0.iconName ?? "exclamationmark.triangle",
                    tint: Color(hex: $0.iconColorHex ?? "#EF4444")
                )
            }
    }

    private var filteredPlaces: [SearchResultItem] {
        visiblePlaces
            .filter {
                matches($0.name)
                    || matches($0.placeDescription)
                    || matches($0.address)
            }
            .prefix(8)
            .map {
                SearchResultItem(
                    route: .place($0.id),
                    title: $0.name,
                    subtitle: subtitle(primary: $0.address, fallback: $0.placeDescription),
                    systemImage: $0.iconName ?? "mappin.and.ellipse",
                    tint: Color(hex: $0.iconColorHex ?? "#10B981")
                )
            }
    }

    private var resultSections: [SearchSection] {
        var sections: [SearchSection] = []

        if selectedScope.matches(.missions), !filteredMissions.isEmpty {
            sections.append(SearchSection(title: "Misje", results: filteredMissions))
        }

        if selectedScope.matches(.notes), !filteredNotes.isEmpty {
            sections.append(SearchSection(title: "Notatki", results: filteredNotes))
        }

        if selectedScope.matches(.lists), !filteredLists.isEmpty {
            sections.append(SearchSection(title: "Listy", results: filteredLists))
        }

        if selectedScope.matches(.incidents), !filteredIncidents.isEmpty {
            sections.append(SearchSection(title: "Incydenty", results: filteredIncidents))
        }

        if selectedScope.matches(.places), !filteredPlaces.isEmpty {
            sections.append(SearchSection(title: "Miejsca", results: filteredPlaces))
        }

        return sections
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Globalne wyszukiwanie")
                .font(.largeTitle.weight(.bold))

            Text("Szukaj w aktualnej grupie. Lokalne wyszukiwanie w widokach takich jak Notatki czy Misje nadal działa osobno.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var scopePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SearchScope.allCases) { scope in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                            selectedScope = scope
                        }
                    } label: {
                        Text(scope.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedScope == scope ? Color.white : Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                selectedScope == scope ? Color.accentColor : AppTheme.Colors.mutedFill,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var searchStartState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Przeszukuj wszystko z jednego miejsca")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                SearchSummaryCard(title: "Misje", count: visibleMissions.count, color: .orange)
                SearchSummaryCard(title: "Notatki", count: visibleNotes.count, color: .blue)
                SearchSummaryCard(title: "Listy", count: visibleLists.count, color: .pink)
                SearchSummaryCard(title: "Incydenty", count: visibleIncidents.count, color: .red)
                SearchSummaryCard(title: "Miejsca", count: visiblePlaces.count, color: .green)
            }

            ContentUnavailableView(
                "Zacznij wpisywać",
                systemImage: "text.magnifyingglass",
                description: Text("Możesz szukać globalnie albo od razu zawęzić wyniki filtrem, np. tylko do notatek lub misji.")
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }

    private func matches(_ value: String?) -> Bool {
        guard !normalizedQuery.isEmpty else { return false }
        guard let value, !value.isEmpty else { return false }
        return value.localizedCaseInsensitiveContains(normalizedQuery)
    }

    private func subtitle(primary: String?, fallback: String?) -> String? {
        let primaryValue = trimmed(primary)
        if let primaryValue, !primaryValue.isEmpty {
            return primaryValue
        }

        let fallbackValue = trimmed(fallback)
        if let fallbackValue, !fallbackValue.isEmpty {
            return fallbackValue
        }

        return nil
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(120))
    }
}

private enum SearchScope: String, CaseIterable, Identifiable {
    case all
    case missions
    case notes
    case lists
    case incidents
    case places

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Wszystko"
        case .missions:
            return "Misje"
        case .notes:
            return "Notatki"
        case .lists:
            return "Listy"
        case .incidents:
            return "Incydenty"
        case .places:
            return "Miejsca"
        }
    }

    func matches(_ other: SearchScope) -> Bool {
        self == .all || self == other
    }
}

private struct SearchSection: Identifiable {
    let id = UUID()
    let title: String
    let results: [SearchResultItem]
}

private struct SearchResultItem: Identifiable {
    let route: RelatedContentRoute
    let title: String
    let subtitle: String?
    let systemImage: String
    let tint: Color

    var id: String { route.id }
}

private struct SearchSummaryCard: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("\(count)")
                .font(.title.weight(.bold))
                .foregroundStyle(color)

            Text("Dostępne w tej grupie")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview("Search") {
    let preview = MainNavigationPreviewFactory.make()

    return NavigationStack {
        PhoneSearchScreen()
    }
    .environment(preview.authRepository)
    .environment(preview.spaceRepository)
    .environment(preview.authStore)
    .environment(preview.notificationStore)
    .modelContainer(preview.container)
}

#endif
