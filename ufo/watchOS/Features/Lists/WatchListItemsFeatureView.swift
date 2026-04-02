#if os(watchOS)
import SwiftUI

struct WatchListItemsFeatureView: View {
    @Environment(WatchAppModel.self) private var model

    let list: WatchSharedListSummary

    @State private var items: [WatchSharedListItemSummary] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if items.isEmpty {
                Text("Brak pozycji.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isCompleted ? .green : .secondary)
                        Text(item.title)
                            .strikethrough(item.isCompleted)
                    }
                }
            }
        }
        .navigationTitle(list.name)
        .task(id: list.id) {
            await loadItems()
        }
    }

    private func loadItems() async {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await model.fetchListItems(listID: list.id)
            errorMessage = nil
        } catch {
            items = []
            errorMessage = "Nie udało się wczytać pozycji."
        }
    }
}

#endif
