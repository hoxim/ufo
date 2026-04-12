import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class MessageStore: SpaceScopedStore {
    let modelContext: ModelContext
    private let repository: MessageRepository

    var messages: [SpaceMessage] = []
    var currentSpaceId: UUID?
    var isSyncing = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, repository: MessageRepository) {
        self.modelContext = modelContext
        self.repository = repository
    }

    // MARK: - SpaceScopedStore

    func clearSpaceData() {
        messages = []
    }

    func loadLocal(spaceId: UUID) {
        do {
            messages = try repository.fetchLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            messages = []
            lastErrorMessage = error.localizedDescription
        }
    }

    func pullRemoteData(spaceId: UUID) async throws {
        try await repository.pullRemoteToLocal(spaceId: spaceId)
    }

    func syncPendingData(spaceId: UUID) async throws {
        try await repository.syncPendingLocal(spaceId: spaceId)
    }

    // MARK: - CRUD

    func sendMessage(body: String, senderId: UUID, senderName: String, recipientIds: [UUID]) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            _ = try repository.createLocal(
                spaceId: spaceId,
                senderId: senderId,
                senderName: senderName,
                body: body,
                recipientIds: recipientIds
            )
            loadLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("messages.error.send", error: error)
        }
    }
}
