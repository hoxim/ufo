#if os(watchOS)
import SwiftUI

struct WatchListsFeatureView: View {
    @Environment(WatchAppModel.self) private var model

    @State private var lists: [WatchSharedListSummary] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        List {
            if isLoading {
                ProgressView("lists.view.loading")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if lists.isEmpty {
                Text("watch.lists.empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(lists) { list in
                    NavigationLink {
                        WatchListItemsFeatureView(list: list)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(list.name)
                            Text(watchLocalizedListType(list.type))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("lists.view.title")
        .task(id: model.selectedSpaceID) {
            await loadLists()
        }
    }

    private func loadLists() async {
        isLoading = true
        defer { isLoading = false }

        do {
            lists = try await model.fetchLists()
            errorMessage = nil
        } catch {
            lists = []
            errorMessage = String(localized: "watch.lists.error.load")
        }
    }
}

#endif
