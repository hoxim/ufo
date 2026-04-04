#if os(iOS)

import SwiftUI
import SwiftData

struct PhoneAddListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo

    let store: SharedListStore
    let actorId: UUID?
    let availablePlaces: [SavedPlace]
    let onCreated: (UUID) -> Void
    var initialSavedPlaceId: UUID? = nil
    var originLabel: String? = nil

    @State private var name = ""
    @State private var selectedType: SharedListType = .shopping
    @State private var selectedIconName = "checklist"
    @State private var selectedIconColorHex = "#6366F1"
    @State private var savedPlaceId: UUID?
    @State private var isSaving = false
    @State private var showStylePicker = false
    @State private var isPresentingAddPlace = false
    @FocusState private var isNameFocused: Bool

    init(
        store: SharedListStore,
        actorId: UUID?,
        availablePlaces: [SavedPlace],
        onCreated: @escaping (UUID) -> Void,
        initialSavedPlaceId: UUID? = nil,
        originLabel: String? = nil
    ) {
        self.store = store
        self.actorId = actorId
        self.availablePlaces = availablePlaces
        self.onCreated = onCreated
        self.initialSavedPlaceId = initialSavedPlaceId
        self.originLabel = originLabel
        _savedPlaceId = State(initialValue: initialSavedPlaceId)
    }

    var body: some View {
        AdaptiveFormContent {
            Form {
                if let originLabel {
                    Section {
                        OpenedFromBadge(title: originLabel)
                    }
                }
                TextField("lists.editor.field.name", text: $name)
                    .prominentFormTextInput()
                    .focused($isNameFocused)
                SelectionMenuRow(title: String(localized: "lists.editor.field.type"), value: selectedType.localizedLabel) {
                    ForEach(SharedListType.allCases) { type in
                        Button(type.localizedLabel) { selectedType = type }
                    }
                }
                SelectionMenuRow(title: String(localized: "lists.editor.field.place"), value: selectedPlaceTitle, isPlaceholder: savedPlaceId == nil) {
                    Button(String(localized: "lists.editor.action.noPlace")) { savedPlaceId = nil }
                    ForEach(resolvedAvailablePlaces) { place in
                        Button(place.name) { savedPlaceId = place.id }
                    }
                    Divider()
                    Button(String(localized: "lists.editor.action.addPlace")) { isPresentingAddPlace = true }
                }
                DisclosureGroup("lists.editor.section.style", isExpanded: $showStylePicker) {
                    OperationStylePicker(iconName: $selectedIconName, colorHex: $selectedIconColorHex)
                }
            }
            .navigationTitle("lists.editor.title.new")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }
                ModalConfirmToolbarItem(
                    isDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving,
                    isProcessing: isSaving,
                    action: {
                        Task {
                            await saveList()
                        }
                    }
                )
            }
            .sheet(isPresented: $isPresentingAddPlace) {
                QuickAddPlaceSheet(originLabel: originLabel) { place in
                    savedPlaceId = place.id
                }
            }
            .onAppear {
                if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    isNameFocused = true
                }
            }
        }
    }

    @MainActor
    private func saveList() async {
        isSaving = true
        defer { isSaving = false }

        let listId = await store.addList(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: selectedType,
            iconName: selectedIconName,
            iconColorHex: selectedIconColorHex,
            savedPlaceId: savedPlaceId,
            savedPlaceName: resolvedAvailablePlaces.first(where: { $0.id == savedPlaceId })?.name,
            actor: actorId
        )
        guard let listId else { return }
        dismiss()
        onCreated(listId)
    }

    private var resolvedAvailablePlaces: [SavedPlace] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return availablePlaces }
        do {
            return try modelContext.fetch(
                FetchDescriptor<SavedPlace>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.name, order: .forward)]
                )
            )
        } catch {
            return availablePlaces
        }
    }

    private var selectedPlaceTitle: String {
        resolvedAvailablePlaces.first(where: { $0.id == savedPlaceId })?.name ?? String(localized: "lists.editor.action.noPlace")
    }
}

struct PhoneListDetailView: View {
    let store: SharedListStore
    let listId: UUID
    let actorId: UUID?
    var openedFromLabel: String? = nil

    @State private var newItemName = ""

    private var list: SharedList? {
        store.lists.first { $0.id == listId }
    }

    private var items: [SharedListItem] {
        store.itemsByList[listId] ?? []
    }

    var body: some View {
        List {
            if let openedFromLabel {
                Section {
                    OpenedFromBadge(title: openedFromLabel)
                }
            }
            if let error = store.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Section("lists.items.section.newItem") {
                HStack {
                    TextField("lists.items.field.name", text: $newItemName)
                        .prominentFormTextInput()
                    Button {
                        Task {
                            await addItem()
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }

            Section("lists.items.section.items") {
                if let savedPlaceName = list?.savedPlaceName, !savedPlaceName.isEmpty {
                    Label(savedPlaceName, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if items.isEmpty {
                    Text("lists.items.empty")
                        .foregroundStyle(.secondary)
                }
                ForEach(items) { item in
                    HStack {
                        Button {
                            Task {
                                await store.toggleItem(item, actor: actorId)
                            }
                        } label: {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isCompleted ? .green : .secondary)
                                .frame(width: 22)
                        }
                        .buttonStyle(.plain)
                        Text(item.title)
                            .strikethrough(item.isCompleted)
                        Spacer()
                        Menu {
                            Button(role: .destructive) {
                                Task {
                                    await store.deleteItem(item, actor: actorId)
                                }
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
                .onDelete { offsets in
                    let values = offsets.map { items[$0] }
                    Task {
                        for item in values {
                            await store.deleteItem(item, actor: actorId)
                        }
                    }
                }
            }
        }
        .navigationTitle(list?.name ?? String(localized: "lists.detail.fallbackTitle"))
        .refreshable {
            await store.syncPending()
            await store.refreshRemote()
        }
        .onAppear {
            let listName = list?.name ?? "nil"
            let knownIds = store.lists.map(\.id.uuidString).joined(separator: ",")
            Log.msg("PhoneListDetailView appear. requestedListId=\(listId.uuidString) resolvedName=\(listName) itemCount=\(items.count) knownListIds=[\(knownIds)]")
            if list == nil {
                Log.error("PhoneListDetailView could not resolve list for listId=\(listId.uuidString)")
            }
        }
    }

    @MainActor
    private func addItem() async {
        let value = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        await store.addItem(listId: listId, title: value)
        newItemName = ""
    }
}

#endif
