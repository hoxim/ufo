import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class NoteStore: SpaceScopedStore {
    let modelContext: ModelContext
    private let repository: NoteRepository

    var notes: [Note] = []
    var folders: [NoteFolder] = []
    var currentSpaceId: UUID?
    var isSyncing = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, repository: NoteRepository) {
        self.modelContext = modelContext
        self.repository = repository
    }

    // MARK: - SpaceScopedStore

    func clearSpaceData() {
        notes = []
        folders = []
    }

    func loadLocal(spaceId: UUID) {
        do {
            notes = try repository.fetchAllLocal(spaceId: spaceId)
            folders = try repository.fetchFoldersLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            notes = []
            folders = []
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Notes require two remote pulls: folders first, then notes.
    func pullRemoteData(spaceId: UUID) async throws {
        try await repository.pullFoldersRemoteToLocal(spaceId: spaceId)
        try await repository.pullRemoteToLocal(spaceId: spaceId)
    }

    /// Notes require two pending syncs: folders first, then notes.
    func syncPendingData(spaceId: UUID) async throws {
        try await repository.syncPendingFoldersLocal(spaceId: spaceId)
        try await repository.syncPendingLocal(spaceId: spaceId)
    }

    func afterSync() {
        notifyHomeWidgetsDataDidChange()
    }

    // MARK: - CRUD

    func addNote(
        title: String,
        content: String,
        folderId: UUID?,
        attachedLinkURL: String?,
        tags: [String],
        isPinned: Bool,
        linkedEntityType: NoteLinkedEntityType?,
        linkedEntityId: UUID?,
        savedPlaceId: UUID?,
        savedPlaceName: String?,
        relatedIncidentId: UUID?,
        relatedLocationLatitude: Double?,
        relatedLocationLongitude: Double?,
        relatedLocationLabel: String?,
        actor: UUID?
    ) async -> Note? {
        guard let spaceId = currentSpaceId else { return nil }
        do {
            let note = try repository.createLocal(
                spaceId: spaceId,
                title: title,
                content: content,
                folderId: folderId,
                attachedLinkURL: attachedLinkURL,
                tags: tags,
                isPinned: isPinned,
                linkedEntityType: linkedEntityType?.rawValue,
                linkedEntityId: linkedEntityId,
                savedPlaceId: savedPlaceId,
                savedPlaceName: savedPlaceName,
                relatedIncidentId: relatedIncidentId,
                relatedLocationLatitude: relatedLocationLatitude,
                relatedLocationLongitude: relatedLocationLongitude,
                relatedLocationLabel: relatedLocationLabel,
                actor: actor
            )
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
            return note
        } catch {
            lastErrorMessage = localizedErrorMessage("notes.error.add", error: error)
            return nil
        }
    }

    func updateNote(
        _ note: Note,
        title: String,
        content: String,
        folderId: UUID?,
        attachedLinkURL: String?,
        tags: [String],
        isPinned: Bool,
        linkedEntityType: NoteLinkedEntityType?,
        linkedEntityId: UUID?,
        savedPlaceId: UUID?,
        savedPlaceName: String?,
        relatedIncidentId: UUID?,
        relatedLocationLatitude: Double?,
        relatedLocationLongitude: Double?,
        relatedLocationLabel: String?,
        actor: UUID?
    ) async {
        do {
            try repository.markUpdatedLocal(
                note,
                title: title,
                content: content,
                folderId: folderId,
                attachedLinkURL: attachedLinkURL,
                tags: tags,
                isPinned: isPinned,
                linkedEntityType: linkedEntityType?.rawValue,
                linkedEntityId: linkedEntityId,
                savedPlaceId: savedPlaceId,
                savedPlaceName: savedPlaceName,
                relatedIncidentId: relatedIncidentId,
                relatedLocationLatitude: relatedLocationLatitude,
                relatedLocationLongitude: relatedLocationLongitude,
                relatedLocationLabel: relatedLocationLabel,
                actor: actor
            )
            if let spaceId = currentSpaceId { loadLocal(spaceId: spaceId) }
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("notes.error.update", error: error)
        }
    }

    func deleteNote(_ note: Note, actor: UUID?) async {
        do {
            try repository.softDeleteLocal(note, actor: actor)
            if let spaceId = currentSpaceId { loadLocal(spaceId: spaceId) }
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("notes.error.delete", error: error)
        }
    }

    func addFolder(name: String, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            _ = try repository.createFolderLocal(spaceId: spaceId, name: name, actor: actor)
            loadLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("notes.error.addFolder", error: error)
        }
    }
}
