#if os(watchOS)
import SwiftUI

struct WatchFeatureMenuView: View {
    @Environment(WatchAppModel.self) private var model

    var body: some View {
        List {
            if !model.spaces.isEmpty {
                Section("Space") {
                    Picker("Aktywny space", selection: selectedSpaceBinding) {
                        ForEach(model.spaces) { space in
                            Text(space.name).tag(space.id)
                        }
                    }
                }
            }

            Section("Features") {
                ForEach(WatchFeatureMenuItem.allCases) { item in
                    NavigationLink {
                        destination(for: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(item.title, systemImage: item.systemImage)
                            Text(item.subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let currentUserEmail = model.currentUserEmail {
                Section("Konto") {
                    VStack(alignment: .leading, spacing: 2) {
                        if let currentUserName = model.currentUserName, !currentUserName.isEmpty {
                            Text(currentUserName)
                        }
                        Text(currentUserEmail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Wyloguj", role: .destructive) {
                        Task {
                            await model.signOut()
                        }
                    }
                }
            }
        }
        .navigationTitle("UFO")
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
        case .incidents:
            WatchIncidentsFeatureView()
        case .lists:
            WatchListsFeatureView()
        case .missions:
            WatchMissionsFeatureView()
        }
    }
}

#endif
