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
            lastErrorMessage = "Nie udało się wczytać lokalnych Space: \(error)"
            spaces = []
        }
    }

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
            lastErrorMessage = "Nie udało się pobrać Space z serwera: \(error)"
            loadLocal()
        }
    }

    func createSpace(name: String, type: SpaceType) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await spaceRepository.createSpace(name: name, type: type)
            await refreshFromRemote()
        } catch {
            lastErrorMessage = "Nie udało się utworzyć Space: \(error)"
        }
    }

    func joinSpace(inviteCode: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await spaceRepository.joinSpace(inviteCode: inviteCode)
            await refreshFromRemote()
        } catch {
            lastErrorMessage = "Nie udało się dołączyć do Space: \(error)"
        }
    }

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
            lastErrorMessage = "Nie udało się opuścić Space: \(error)"
        }
    }

    func selectSpace(_ space: Space?) {
        selectedSpace = space
        spaceRepository.selectedSpace = space
    }

    private func fetchLocalSpace(id: UUID) throws -> Space? {
        let descriptor = FetchDescriptor<Space>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
}
