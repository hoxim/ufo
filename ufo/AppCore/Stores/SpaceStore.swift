import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SpaceStore {
    private let modelContext: ModelContext
    private let spaceRepository: SpaceRepository

    var spaces: [Space] = []
    var selectedSpace: Space?
    var isLoading: Bool = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, spaceRepository: SpaceRepository) {
        self.modelContext = modelContext
        self.spaceRepository = spaceRepository
        loadLocal()
        selectedSpace = spaceRepository.selectedSpace
    }

    /// Loads local.
    func loadLocal() {
        do {
            spaces = try modelContext.fetch(
                FetchDescriptor<Space>(
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
            if selectedSpace == nil {
                selectedSpace = spaces.first
            }
        } catch {
            lastErrorMessage = localizedErrorMessage("spaces.error.loadLocal", error: error)
            spaces = []
        }
    }

    /// Handles refresh from remote.
    func refreshFromRemote() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let remoteSpaces = try await spaceRepository.getSpaces()
            for remote in remoteSpaces {
                if let local = try fetchLocalSpace(id: remote.id) {
                    local.name = remote.name
                    local.inviteCode = remote.inviteCode
                    local.updatedAt = .now
                    local.version = max(local.version, remote.version)
                } else {
                    modelContext.insert(remote)
                }
            }

            try modelContext.save()
            loadLocal()
            spaceRepository.restoreLastSelectedSpace(from: spaces)
            selectedSpace = spaceRepository.selectedSpace
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = localizedErrorMessage("spaces.error.refresh", error: error)
            loadLocal()
        }
    }

    /// Creates space.
    func createSpace(name: String, type: SpaceType) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await spaceRepository.createSpace(name: name, type: type)
            await refreshFromRemote()
        } catch {
            lastErrorMessage = localizedErrorMessage("spaces.error.create", error: error)
        }
    }

    /// Handles join space.
    func joinSpace(inviteCode: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await spaceRepository.joinSpace(inviteCode: inviteCode)
            await refreshFromRemote()
        } catch {
            lastErrorMessage = localizedErrorMessage("spaces.error.join", error: error)
        }
    }

    /// Handles leave space.
    func leaveSpace(spaceId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await spaceRepository.leaveSpace(spaceId: spaceId)
            if let local = try fetchLocalSpace(id: spaceId) {
                modelContext.delete(local)
                try modelContext.save()
            }
            loadLocal()
            if selectedSpace?.id == spaceId {
                selectedSpace = spaces.first
                spaceRepository.selectedSpace = selectedSpace
            }
        } catch {
            lastErrorMessage = localizedErrorMessage("spaces.error.leave", error: error)
        }
    }

    /// Handles select space.
    func selectSpace(_ space: Space?) {
        selectedSpace = space
        spaceRepository.selectedSpace = space
    }

    /// Fetches local space.
    private func fetchLocalSpace(id: UUID) throws -> Space? {
        let descriptor = FetchDescriptor<Space>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
}
