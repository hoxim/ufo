import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class LinkStore {
    private let modelContext: ModelContext
    private let repository: LinkRepository
    private var cloudSyncEnabled: Bool { AppPreferences.shared.isCloudSyncEnabled }

    var links: [LinkedThing] = []
    var currentScopeId: UUID?
    var isSyncing: Bool = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, repository: LinkRepository) {
        self.modelContext = modelContext
        self.repository = repository
    }

    /// Sets scope.
    func setScope(_ scopeId: UUID?) {
        currentScopeId = scopeId
        guard let scopeId else {
            links = []
            return
        }
        loadLocal(scopeId: scopeId)
    }

    /// Loads local.
    func loadLocal(scopeId: UUID) {
        do {
            links = try repository.fetchAllLocal(scopeId: scopeId)
            lastErrorMessage = nil
        } catch {
            links = []
            lastErrorMessage = "Nie udało się wczytać linków lokalnie: \(error)"
        }
    }

    /// Handles refresh remote.
    func refreshRemote() async {
        guard let scopeId = currentScopeId else { return }
        guard cloudSyncEnabled else {
            loadLocal(scopeId: scopeId)
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.pullRemoteToLocal(scopeId: scopeId)
            links = try repository.fetchAllLocal(scopeId: scopeId)
            lastErrorMessage = nil
        } catch {
            loadLocal(scopeId: scopeId)
            lastErrorMessage = "Nie udało się odświeżyć linków: \(error)"
        }
    }

    /// Handles add link.
    func addLink(parentId: UUID, childId: UUID, actor: UUID?) async {
        guard let scopeId = currentScopeId else { return }

        do {
            _ = try repository.createLocal(thingId: scopeId, parentId: parentId, childId: childId, actor: actor)
            links = try repository.fetchAllLocal(scopeId: scopeId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się dodać linku: \(error)"
        }
    }

    /// Deletes link.
    func deleteLink(_ link: LinkedThing, actor: UUID?) async {
        guard let scopeId = currentScopeId else { return }

        do {
            try repository.softDeleteLocal(link, actor: actor)
            links = try repository.fetchAllLocal(scopeId: scopeId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się usunąć linku: \(error)"
        }
    }

    /// Syncs pending.
    func syncPending() async {
        guard let scopeId = currentScopeId else { return }
        guard cloudSyncEnabled else {
            loadLocal(scopeId: scopeId)
            lastErrorMessage = nil
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.syncPendingLocal(scopeId: scopeId)
            try await repository.pullRemoteToLocal(scopeId: scopeId)
            links = try repository.fetchAllLocal(scopeId: scopeId)
            try modelContext.save()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Nie udało się zsynchronizować linków: \(error)"
        }
    }
}
