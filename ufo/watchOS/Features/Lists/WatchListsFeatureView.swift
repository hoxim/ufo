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
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if lists.isEmpty {
                Text("Brak list w tym space.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(lists) { list in
                    NavigationLink {
                        WatchListItemsFeatureView(list: list)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(list.name)
                            Text(list.type.capitalized)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Lists")
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
            errorMessage = "Nie udało się wczytać list."
        }
    }
}

#endif
