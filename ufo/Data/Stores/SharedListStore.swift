import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SharedListStore {
    private let modelContext: ModelContext
    private let repository: SharedListRepository

    var lists: [SharedList] = []
    var itemsByList: [UUID: [SharedListItem]] = [:]
    var currentSpaceId: UUID?
    var isSyncing: Bool = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, repository: SharedListRepository) {
        self.modelContext = modelContext
        self.repository = repository
    }

    /// Sets space.
    func setSpace(_ spaceId: UUID?) {
        currentSpaceId = spaceId
        guard let spaceId else {
            lists = []
            itemsByList = [:]
            return
        }
        loadLocal(spaceId: spaceId)
    }

    /// Loads local.
    func loadLocal(spaceId: UUID) {
        do {
            lists = try repository.fetchListsLocal(spaceId: spaceId)
            var map: [UUID: [SharedListItem]] = [:]
            for list in lists {
                map[list.id] = try repository.fetchItemsLocal(listId: list.id)
            }
            itemsByList = map
            lastErrorMessage = nil
        } catch {
            lists = []
            itemsByList = [:]
            lastErrorMessage = "Nie udało się wczytać list: \(error)"
        }
    }

    /// Handles refresh remote.
    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            loadLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = "Nie udało się odświeżyć list: \(error)"
        }
    }

    @discardableResult
    /// Adds list and returns new list id when success.
    func addList(name: String, type: SharedListType, iconName: String?, iconColorHex: String?, actor: UUID?) async -> UUID? {
        guard let spaceId = currentSpaceId else { return nil }
        do {
            let list = try repository.createListLocal(
                spaceId: spaceId,
                name: name,
                type: type,
                iconName: iconName,
                iconColorHex: iconColorHex,
                actor: actor
            )
            loadLocal(spaceId: spaceId)
            await syncPending()
            return list.id
        } catch {
            lastErrorMessage = "Nie udało się dodać listy: \(error)"
            return nil
        }
    }

    /// Handles add item.
    func addItem(listId: UUID, title: String) async {
        guard currentSpaceId != nil else { return }
        do {
            let nextPosition = (itemsByList[listId]?.count ?? 0) + 1
            _ = try repository.createItemLocal(listId: listId, title: title, position: nextPosition)
            if let spaceId = currentSpaceId { loadLocal(spaceId: spaceId) }
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się dodać pozycji listy: \(error)"
        }
    }

    /// Toggles item.
    func toggleItem(_ item: SharedListItem, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            try repository.toggleItemLocal(item, actor: actor)
            loadLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się zaktualizować pozycji listy: \(error)"
        }
    }

    /// Deletes item.
    func deleteItem(_ item: SharedListItem, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            try repository.deleteItemLocal(item, actor: actor)
            loadLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się usunąć pozycji listy: \(error)"
        }
    }

    /// Syncs pending.
    func syncPending() async {
        guard let spaceId = currentSpaceId else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.syncPendingLocal(spaceId: spaceId)
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            loadLocal(spaceId: spaceId)
            try modelContext.save()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Nie udało się zsynchronizować list: \(error)"
        }
    }
}
