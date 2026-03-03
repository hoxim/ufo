import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class NoteStore {
    private let modelContext: ModelContext
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
            lastErrorMessage = "Nie udało się wczytać notatek: \(error)"
        }
    }

    /// Pulls latest notes from remote and merges to local.
    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
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
            lastErrorMessage = "Nie udało się odświeżyć notatek: \(error)"
        }
    }

    /// Creates one note with optional link, incident and location attachment.
    func addNote(
        title: String,
        content: String,
        folderId: UUID?,
        attachedLinkURL: String?,
        relatedIncidentId: UUID?,
        relatedLocationLatitude: Double?,
        relatedLocationLongitude: Double?,
        relatedLocationLabel: String?,
        actor: UUID?
    ) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            _ = try repository.createLocal(
                spaceId: spaceId,
                title: title,
                content: content,
                folderId: folderId,
                attachedLinkURL: attachedLinkURL,
                relatedIncidentId: relatedIncidentId,
                relatedLocationLatitude: relatedLocationLatitude,
                relatedLocationLongitude: relatedLocationLongitude,
                relatedLocationLabel: relatedLocationLabel,
                actor: actor
            )
            notes = try repository.fetchAllLocal(spaceId: spaceId)
            folders = try repository.fetchFoldersLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się dodać notatki: \(error)"
        }
    }

    /// Updates existing note and syncs it to remote.
    func updateNote(
        _ note: Note,
        title: String,
        content: String,
        folderId: UUID?,
        attachedLinkURL: String?,
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
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się zaktualizować notatki: \(error)"
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
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się usunąć notatki: \(error)"
        }
    }

    /// Syncs pending local mutations and reloads latest notes.
    func syncPending() async {
        guard let spaceId = currentSpaceId else { return }
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
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Nie udało się zsynchronizować notatek: \(error)"
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
            lastErrorMessage = "Nie udało się dodać folderu: \(error)"
        }
    }
}
