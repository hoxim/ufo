#if os(watchOS)
import SwiftUI

struct WatchPeopleFeatureView: View {
    @Environment(WatchAppModel.self) private var model

    @State private var people: [WatchPersonSummary] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        List {
            if isLoading {
                ProgressView("watch.people.loading")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if people.isEmpty {
                Text("watch.people.empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(people) { person in
                    NavigationLink {
                        WatchPersonDetailScreen(person: person)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.displayName)
                            Text(watchLocalizedSpaceRole(person.role))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("watch.people.title")
        .task(id: model.selectedSpaceID) {
            await loadPeople()
        }
        .refreshable {
            await loadPeople()
        }
    }

    private func loadPeople() async {
        isLoading = true
        defer { isLoading = false }

        do {
            people = try await model.fetchPeople()
            errorMessage = nil
        } catch {
            people = []
            errorMessage = String(localized: "watch.people.error.load")
        }
    }
}

private struct WatchPersonDetailScreen: View {
    let person: WatchPersonSummary

    var body: some View {
        List {
            Section("watch.people.role") {
                Text(watchLocalizedSpaceRole(person.role))
            }

            if !person.email.isEmpty {
                Section("watch.people.email") {
                    Text(person.email)
                        .font(.footnote)
                }
            }

            Section("watch.common.largerScreen") {
                Text("watch.people.handoff")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(person.displayName)
    }
}

#endif
