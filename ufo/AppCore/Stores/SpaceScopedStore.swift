import Foundation
import SwiftData

/// A protocol for `@Observable` stores that manage data scoped to a single Space.
///
/// Conforming stores get `setSpace(_:)`, `refreshRemote()`, and `syncPending()` for free.
/// Each store only needs to implement four focused methods:
///   - `clearSpaceData()` — clear in-memory arrays when space is deselected
///   - `loadLocal(spaceId:)` — fetch data from local SwiftData
///   - `pullRemoteData(spaceId:)` — pull from Supabase into local store
///   - `syncPendingData(spaceId:)` — push pending local mutations to Supabase
///
/// Override `afterSync()` for post-sync side effects (e.g. home widget notifications).
@MainActor
protocol SpaceScopedStore: AnyObject {

    // MARK: - Required stored properties

    var modelContext: ModelContext { get }
    var currentSpaceId: UUID? { get set }
    var isSyncing: Bool { get set }
    var lastErrorMessage: String? { get set }

    // MARK: - Required implementations

    /// Empties all in-memory data arrays. Called when space becomes `nil`.
    func clearSpaceData()

    /// Fetches all relevant data for the given space from the local SwiftData store.
    /// Must set `lastErrorMessage` on failure.
    func loadLocal(spaceId: UUID)

    /// Pulls the latest data from remote into local SwiftData.
    func pullRemoteData(spaceId: UUID) async throws

    /// Pushes all pending local mutations to remote.
    func syncPendingData(spaceId: UUID) async throws

    // MARK: - Optional hook

    /// Called after a successful `syncPending()` cycle.
    /// Default implementation is a no-op.
    func afterSync()
}

// MARK: - Default implementations

extension SpaceScopedStore {

    func afterSync() {}

    private var cloudSyncEnabled: Bool {
        AppPreferences.shared.isCloudSyncEnabled
    }

    /// Sets the active space and immediately loads data from local store.
    func setSpace(_ spaceId: UUID?) {
        currentSpaceId = spaceId
        guard let spaceId else {
            clearSpaceData()
            return
        }
        loadLocal(spaceId: spaceId)
    }

    /// Pulls fresh data from remote (if cloud sync is enabled) and reloads local cache.
    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
        guard cloudSyncEnabled else {
            loadLocal(spaceId: spaceId)
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await pullRemoteData(spaceId: spaceId)
            loadLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Pushes pending local changes to remote, then pulls the latest state.
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
            try await syncPendingData(spaceId: spaceId)
            try await pullRemoteData(spaceId: spaceId)
            loadLocal(spaceId: spaceId)
            try? modelContext.save()
            afterSync()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
