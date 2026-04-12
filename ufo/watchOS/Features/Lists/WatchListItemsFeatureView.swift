#if os(watchOS)
import SwiftUI

struct WatchListItemsFeatureView: View {
    @Environment(WatchAppModel.self) private var model

    let list: WatchSharedListSummary

    @State private var items: [WatchSharedListItemSummary] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isPresentingAddSheet = false

    var body: some View {
        List {
            if isLoading {
                ProgressView("watch.lists.items.loading")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if items.isEmpty {
                Text("lists.items.empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    NavigationLink {
                        WatchListItemDetailScreen(item: item) {
                            await loadItems()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isCompleted ? .green : .secondary)
                            Text(item.title)
                                .strikethrough(item.isCompleted)
                        }
                    }
                }
            }
        }
        .navigationTitle(list.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddSheet) {
            WatchListItemEditorScreen(titleKey: "watch.lists.items.newTitle", actionTitleKey: "watch.common.add") { title in
                try await model.addListItem(listID: list.id, title: title, position: items.count + 1)
                await loadItems()
            }
        }
        .task(id: list.id) {
            await loadItems()
        }
        .refreshable {
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
            errorMessage = String(localized: "watch.lists.items.error.load")
        }
    }
}

private struct WatchListItemDetailScreen: View {
    @Environment(WatchAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let item: WatchSharedListItemSummary
    let onDidChange: @Sendable () async -> Void

    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        List {
            Section("watch.lists.items.detail.section.item") {
                HStack(spacing: 8) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isCompleted ? .green : .secondary)
                    Text(item.title)
                        .strikethrough(item.isCompleted)
                }
            }

            Section("watch.common.actions") {
                Button(item.isCompleted ? "watch.lists.items.action.markIncomplete" : "watch.lists.items.action.markComplete") {
                    Task {
                        await toggle()
                    }
                }
                .disabled(isSaving)

                Button("common.delete", role: .destructive) {
                    Task {
                        await delete()
                    }
                }
                .disabled(isSaving)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(item.title)
    }

    private func toggle() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await model.toggleListItem(item)
            await onDidChange()
            dismiss()
        } catch {
            errorMessage = String(localized: "watch.lists.items.error.update")
        }
    }

    private func delete() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await model.deleteListItem(item)
            await onDidChange()
            dismiss()
        } catch {
            errorMessage = String(localized: "watch.lists.items.error.delete")
        }
    }
}

private struct WatchListItemEditorScreen: View {
    @Environment(\.dismiss) private var dismiss

    let titleKey: String
    let actionTitleKey: String
    let onSave: @Sendable (String) async throws -> Void

    @State private var itemTitle = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        List {
            Section("notes.editor.field.title") {
                TextField("watch.lists.items.field.placeholder", text: $itemTitle)
            }

            Section {
                Button(actionTitleKey) {
                    Task {
                        await save()
                    }
                }
                .disabled(isSaving || trimmedTitle.isEmpty)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(titleKey)
    }

    private var trimmedTitle: String {
        itemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await onSave(trimmedTitle)
            dismiss()
        } catch {
            errorMessage = String(localized: "watch.lists.items.error.create")
        }
    }
}

#Preview("Watch List Item Detail") {
    let model = WatchAppModel()
    let item = WatchSharedListItemSummary(
        id: UUID(),
        title: "Milk",
        isCompleted: false,
        position: 1,
        version: 1
    )

    return NavigationStack {
        WatchListItemDetailScreen(item: item, onDidChange: {})
            .environment(model)
    }
}

#Preview("Watch List Item Editor") {
    NavigationStack {
        WatchListItemEditorScreen(
            titleKey: "watch.lists.items.newTitle",
            actionTitleKey: "watch.common.add"
        ) { _ in }
    }
}

#endif
