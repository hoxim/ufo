import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class MessageStore {
    private let modelContext: ModelContext
    private let repository: MessageRepository

    var messages: [SpaceMessage] = []
    var currentSpaceId: UUID?
    var isSyncing: Bool = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, repository: MessageRepository) {
        self.modelContext = modelContext
        self.repository = repository
    }

    func setSpace(_ spaceId: UUID?) {
        currentSpaceId = spaceId
        guard let spaceId else {
            messages = []
            return
        }
        loadLocal(spaceId: spaceId)
    }

    func loadLocal(spaceId: UUID) {
        do {
            messages = try repository.fetchLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            messages = []
            lastErrorMessage = "Nie udało się wczytać wiadomości: \(error)"
        }
    }

    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            messages = try repository.fetchLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = "Nie udało się odświeżyć wiadomości: \(error)"
        }
    }

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
            messages = try repository.fetchLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się wysłać wiadomości: \(error)"
        }
    }

    func syncPending() async {
        guard let spaceId = currentSpaceId else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.syncPendingLocal(spaceId: spaceId)
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            messages = try repository.fetchLocal(spaceId: spaceId)
            try modelContext.save()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Nie udało się zsynchronizować wiadomości: \(error)"
        }
    }
}
