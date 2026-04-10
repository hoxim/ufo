#if os(watchOS)
import SwiftUI

struct WatchFeatureMenuView: View {
    @Environment(WatchAppModel.self) private var model

    var body: some View {
        List {
            if !model.spaces.isEmpty {
                Section("watch.feature.menu.spaceSection") {
                    Picker("watch.feature.menu.spacePicker", selection: selectedSpaceBinding) {
                        ForEach(model.spaces) { space in
                            Text(space.name).tag(space.id)
                        }
                    }
                }
            }

            Section("watch.feature.menu.featuresSection") {
                ForEach(WatchFeatureMenuItem.allCases) { item in
                    NavigationLink {
                        destination(for: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(item.titleKey, systemImage: item.systemImage)
                            Text(item.subtitleKey)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let currentUserEmail = model.currentUserEmail {
                Section("watch.feature.menu.accountSection") {
                    VStack(alignment: .leading, spacing: 2) {
                        if let currentUserName = model.currentUserName, !currentUserName.isEmpty {
                            Text(currentUserName)
                        }
                        Text(currentUserEmail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("watch.feature.menu.signOut", role: .destructive) {
                        Task {
                            await model.signOut()
                        }
                    }
                }
            }
        }
        .navigationTitle("watch.feature.menu.title")
    }

    private var selectedSpaceBinding: Binding<UUID> {
        Binding(
            get: { model.selectedSpaceID ?? model.spaces.first?.id ?? UUID() },
            set: { model.selectSpace(id: $0) }
        )
    }

    @ViewBuilder
    private func destination(for item: WatchFeatureMenuItem) -> some View {
        switch item {
        case .notes:
            WatchNotesFeatureView()
        case .routines:
            WatchRoutinesFeatureView()
        case .locations:
            WatchLocationsFeatureView()
        case .people:
            WatchPeopleFeatureView()
        case .notifications:
            WatchNotificationsFeatureView()
        case .incidents:
            WatchIncidentsFeatureView()
        case .lists:
            WatchListsFeatureView()
        case .missions:
            WatchMissionsFeatureView()
        case .budget:
            WatchBudgetFeatureView()
        }
    }
}

#Preview("Watch Feature Menu") {
    let model = WatchAppModel()
    model.currentUserName = "Preview User"
    model.currentUserEmail = "preview@ufo.app"
    model.spaces = [
        WatchSpaceSummary(id: UUID(), name: "Family Crew", role: "admin"),
        WatchSpaceSummary(id: UUID(), name: "Work", role: "member")
    ]
    model.selectedSpaceID = model.spaces.first?.id

    return NavigationStack {
        WatchFeatureMenuView()
            .environment(model)
    }
}

#endif
