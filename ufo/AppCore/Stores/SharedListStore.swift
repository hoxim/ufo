import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SharedListStore {
    private let modelContext: ModelContext
    private let repository: SharedListRepository
    private var cloudSyncEnabled: Bool { AppPreferences.shared.isCloudSyncEnabled }

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
        Log.msg("SharedListStore.setSpace spaceId=\(spaceId?.uuidString ?? "nil")")
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
            let summary = lists.map { "\($0.id.uuidString)=\($0.name)" }.joined(separator: ", ")
            Log.msg("SharedListStore.loadLocal spaceId=\(spaceId.uuidString) lists=\(lists.count) summary=[\(summary)]")
        } catch {
            lists = []
            itemsByList = [:]
            lastErrorMessage = localizedErrorMessage("lists.error.load", error: error)
            Log.error("SharedListStore.loadLocal failed for spaceId=\(spaceId.uuidString): \(error.localizedDescription)")
        }
    }

    /// Handles refresh remote.
    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
        guard cloudSyncEnabled else {
            loadLocal(spaceId: spaceId)
            return
        }
        Log.msg("SharedListStore.refreshRemote start spaceId=\(spaceId.uuidString)")
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            loadLocal(spaceId: spaceId)
            lastErrorMessage = nil
            Log.msg("SharedListStore.refreshRemote success spaceId=\(spaceId.uuidString)")
        } catch {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = localizedErrorMessage("lists.error.refresh", error: error)
            Log.error("SharedListStore.refreshRemote failed for spaceId=\(spaceId.uuidString): \(error.localizedDescription)")
        }
    }

    @discardableResult
    /// Adds list and returns new list id when success.
    func addList(
        name: String,
        type: SharedListType,
        iconName: String?,
        iconColorHex: String?,
        savedPlaceId: UUID?,
        savedPlaceName: String?,
        actor: UUID?
    ) async -> UUID? {
        guard let spaceId = currentSpaceId else { return nil }
        do {
            let list = try repository.createListLocal(
                spaceId: spaceId,
                name: name,
                type: type,
                iconName: iconName,
                iconColorHex: iconColorHex,
                savedPlaceId: savedPlaceId,
                savedPlaceName: savedPlaceName,
                actor: actor
            )
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
            return list.id
        } catch {
            lastErrorMessage = localizedErrorMessage("lists.error.addList", error: error)
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
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("lists.error.addItem", error: error)
        }
    }

    /// Deletes list.
    func deleteList(_ list: SharedList, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            try repository.deleteListLocal(list, actor: actor)
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("lists.error.deleteList", error: error)
        }
    }

    /// Toggles item.
    func toggleItem(_ item: SharedListItem, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            try repository.toggleItemLocal(item, actor: actor)
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("lists.error.updateItem", error: error)
        }
    }

    /// Deletes item.
    func deleteItem(_ item: SharedListItem, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            try repository.deleteItemLocal(item, actor: actor)
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("lists.error.deleteItem", error: error)
        }
    }

    /// Syncs pending.
    func syncPending() async {
        guard let spaceId = currentSpaceId else { return }
        guard cloudSyncEnabled else {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = nil
            return
        }
        Log.msg("SharedListStore.syncPending start spaceId=\(spaceId.uuidString)")
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.syncPendingLocal(spaceId: spaceId)
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            loadLocal(spaceId: spaceId)
            try modelContext.save()
            notifyHomeWidgetsDataDidChange()
            lastErrorMessage = nil
            Log.msg("SharedListStore.syncPending success spaceId=\(spaceId.uuidString)")
        } catch {
            lastErrorMessage = localizedErrorMessage("lists.error.sync", error: error)
            Log.error("SharedListStore.syncPending failed for spaceId=\(spaceId.uuidString): \(error.localizedDescription)")
        }
    }
}
