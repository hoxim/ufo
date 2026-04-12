import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SharedListStore: SpaceScopedStore {
    let modelContext: ModelContext
    private let repository: SharedListRepository

    var lists: [SharedList] = []
    var itemsByList: [UUID: [SharedListItem]] = [:]
    var currentSpaceId: UUID?
    var isSyncing = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, repository: SharedListRepository) {
        self.modelContext = modelContext
        self.repository = repository
    }

    // MARK: - SpaceScopedStore

    func clearSpaceData() {
        lists = []
        itemsByList = [:]
    }

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
            lastErrorMessage = error.localizedDescription
        }
    }

    func pullRemoteData(spaceId: UUID) async throws {
        try await repository.pullRemoteToLocal(spaceId: spaceId)
    }

    func syncPendingData(spaceId: UUID) async throws {
        try await repository.syncPendingLocal(spaceId: spaceId)
    }

    func afterSync() {
        notifyHomeWidgetsDataDidChange()
    }

    // MARK: - CRUD

    @discardableResult
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

    func addItem(listId: UUID, title: String) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            let nextPosition = (itemsByList[listId]?.count ?? 0) + 1
            _ = try repository.createItemLocal(listId: listId, title: title, position: nextPosition)
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("lists.error.addItem", error: error)
        }
    }

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
}
