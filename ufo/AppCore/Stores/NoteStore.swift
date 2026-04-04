import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class NoteStore {
    private let modelContext: ModelContext
    private let repository: NoteRepository
    private var cloudSyncEnabled: Bool { AppPreferences.shared.isCloudSyncEnabled }

    var notes: [Note] = []
    var folders: [NoteFolder] = []
    var currentSpaceId: UUID?
    var isSyncing = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, repository: NoteRepository) {
        self.modelContext = modelContext
        self.repository = repository
    }

    /// Assigns active space and refreshes local cache for this scope.
    func setSpace(_ spaceId: UUID?) {
        currentSpaceId = spaceId
        guard let spaceId else {
            notes = []
            folders = []
            return
        }
        loadLocal(spaceId: spaceId)
    }

    /// Loads local notes for currently selected space.
    func loadLocal(spaceId: UUID) {
        do {
            notes = try repository.fetchAllLocal(spaceId: spaceId)
            folders = try repository.fetchFoldersLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            notes = []
            folders = []
            lastErrorMessage = localizedErrorMessage("notes.error.load", error: error)
        }
    }

    /// Pulls latest notes from remote and merges to local.
    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
        guard cloudSyncEnabled else {
            loadLocal(spaceId: spaceId)
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await repository.pullFoldersRemoteToLocal(spaceId: spaceId)
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            notes = try repository.fetchAllLocal(spaceId: spaceId)
            folders = try repository.fetchFoldersLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = localizedErrorMessage("notes.error.refresh", error: error)
        }
    }

    /// Creates one note with optional link, incident and location attachment.
    func addNote(
        title: String,
        content: String,
        folderId: UUID?,
        attachedLinkURL: String?,
        tags: [String],
        isPinned: Bool,
        linkedEntityType: String?,
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
                linkedEntityType: linkedEntityType,
                linkedEntityId: linkedEntityId,
                savedPlaceId: savedPlaceId,
                savedPlaceName: savedPlaceName,
                relatedIncidentId: relatedIncidentId,
                relatedLocationLatitude: relatedLocationLatitude,
                relatedLocationLongitude: relatedLocationLongitude,
                relatedLocationLabel: relatedLocationLabel,
                actor: actor
            )
            notes = try repository.fetchAllLocal(spaceId: spaceId)
            folders = try repository.fetchFoldersLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
            return note
        } catch {
            lastErrorMessage = localizedErrorMessage("notes.error.add", error: error)
            return nil
        }
    }

    /// Updates existing note and syncs it to remote.
    func updateNote(
        _ note: Note,
        title: String,
        content: String,
        folderId: UUID?,
        attachedLinkURL: String?,
        tags: [String],
        isPinned: Bool,
        linkedEntityType: String?,
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
                linkedEntityType: linkedEntityType,
                linkedEntityId: linkedEntityId,
                savedPlaceId: savedPlaceId,
                savedPlaceName: savedPlaceName,
                relatedIncidentId: relatedIncidentId,
                relatedLocationLatitude: relatedLocationLatitude,
                relatedLocationLongitude: relatedLocationLongitude,
                relatedLocationLabel: relatedLocationLabel,
                actor: actor
            )
            if let spaceId = currentSpaceId {
                notes = try repository.fetchAllLocal(spaceId: spaceId)
                folders = try repository.fetchFoldersLocal(spaceId: spaceId)
            }
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("notes.error.update", error: error)
        }
    }

    /// Soft-deletes note and syncs deletion.
    func deleteNote(_ note: Note, actor: UUID?) async {
        do {
            try repository.softDeleteLocal(note, actor: actor)
            if let spaceId = currentSpaceId {
                notes = try repository.fetchAllLocal(spaceId: spaceId)
                folders = try repository.fetchFoldersLocal(spaceId: spaceId)
            }
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("notes.error.delete", error: error)
        }
    }

    /// Syncs pending local mutations and reloads latest notes.
    func syncPending() async {
        guard let spaceId = currentSpaceId else { return }
        guard cloudSyncEnabled else {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = nil
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await repository.syncPendingFoldersLocal(spaceId: spaceId)
            try await repository.syncPendingLocal(spaceId: spaceId)
            try await repository.pullFoldersRemoteToLocal(spaceId: spaceId)
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            notes = try repository.fetchAllLocal(spaceId: spaceId)
            folders = try repository.fetchFoldersLocal(spaceId: spaceId)
            try modelContext.save()
            notifyHomeWidgetsDataDidChange()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = localizedErrorMessage("notes.error.sync", error: error)
        }
    }

    /// Creates note folder for currently selected space and syncs it.
    func addFolder(name: String, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            _ = try repository.createFolderLocal(spaceId: spaceId, name: name, actor: actor)
            folders = try repository.fetchFoldersLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("notes.error.addFolder", error: error)
        }
    }
}
