import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class IncidentStore {
    private let modelContext: ModelContext
    private let repository: IncidentRepository

    var incidents: [Incident] = []
    var isSyncing: Bool = false
    var lastErrorMessage: String?
    var currentSpaceId: UUID?

    init(modelContext: ModelContext, repository: IncidentRepository) {
        self.modelContext = modelContext
        self.repository = repository
    }

    /// Sets space.
    func setSpace(_ spaceId: UUID?) {
        currentSpaceId = spaceId
        guard let spaceId else {
            incidents = []
            return
        }
        loadLocal(spaceId: spaceId)
    }

    /// Loads local.
    func loadLocal(spaceId: UUID) {
        do {
            incidents = try repository.fetchAllLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            incidents = []
            lastErrorMessage = "Nie udało się wczytać lokalnych Incidents: \(error)"
        }
    }

    /// Handles refresh remote.
    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            incidents = try repository.fetchAllLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = "Nie udało się odświeżyć Incidents z serwera: \(error)"
        }
    }

    /// Handles add incident.
    func addIncident(title: String, description: String?, occurrenceDate: Date, iconName: String?, iconColorHex: String?, imageData: Data?, userId: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            let incident = try repository.createLocal(
                spaceId: spaceId,
                title: title,
                description: description,
                occurrenceDate: occurrenceDate,
                createdBy: userId
            )
            incident.iconName = iconName
            incident.iconColorHex = iconColorHex
            incident.imageData = imageData
            incident.pendingSync = true
            incidents = try repository.fetchAllLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się dodać Incident: \(error)"
        }
    }

    /// Updates incident.
    func updateIncident(
        _ incident: Incident,
        title: String? = nil,
        description: String? = nil,
        occurrenceDate: Date? = nil,
        iconName: String? = nil,
        iconColorHex: String? = nil,
        imageData: Data? = nil,
        userId: UUID?
    ) async {
        do {
            try repository.markUpdatedLocal(
                incident,
                title: title,
                description: description,
                occurrenceDate: occurrenceDate,
                updatedBy: userId
            )
            if let iconName {
                incident.iconName = iconName
            }
            if let iconColorHex {
                incident.iconColorHex = iconColorHex
            }
            if let imageData {
                incident.imageData = imageData
            }
            incident.pendingSync = true
            if let spaceId = currentSpaceId {
                incidents = try repository.fetchAllLocal(spaceId: spaceId)
            }
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się zaktualizować Incident: \(error)"
        }
    }

    /// Deletes incident.
    func deleteIncident(_ incident: Incident, userId: UUID?) async {
        do {
            try repository.softDeleteLocal(incident, updatedBy: userId)
            if let spaceId = currentSpaceId {
                incidents = try repository.fetchAllLocal(spaceId: spaceId)
            }
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się usunąć Incident: \(error)"
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
            incidents = try repository.fetchAllLocal(spaceId: spaceId)
            try modelContext.save()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Nie udało się zsynchronizować Incidents: \(error)"
        }
    }
}
