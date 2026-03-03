import Foundation
import SwiftData
import Supabase

@MainActor
final class AssignmentRepository {

    private let client: SupabaseClient
    private let context: ModelContext?

    init(client: SupabaseClient, context: ModelContext? = nil) {
        self.client = client
        self.context = context
    }

    private struct AssignmentPayload: Encodable {
        let id: UUID
        let thing_id: UUID
        let user_id: UUID?
        let role: String
        let created_at: Date
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    /// Fetches all local.
    func fetchAllLocal(thingId: UUID) throws -> [Assignment] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<Assignment>(
                predicate: #Predicate { $0.thingId == thingId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    /// Creates local.
    func createLocal(thingId: UUID, userId: UUID?, role: String, actor: UUID?) throws -> Assignment {
        guard let context else { throw RepositoryError.missingLocalContext }
        let assignment = Assignment(
            thingId: thingId,
            userId: userId,
            role: role,
            updatedBy: actor
        )
        context.insert(assignment)
        try context.save()
        return assignment
    }

    /// Updates local.
    func updateLocal(_ assignment: Assignment, role: String, actor: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        assignment.role = role
        assignment.updatedBy = actor
        assignment.version += 1
        assignment.updatedAt = .now
        try context?.save()
    }

    /// Handles soft delete local.
    func softDeleteLocal(_ assignment: Assignment, actor: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        assignment.deletedAt = .now
        assignment.updatedBy = actor
        assignment.version += 1
        assignment.updatedAt = .now
        try context?.save()
    }

    /// Handles upsert remote.
    func upsertRemote(_ assignment: Assignment) async throws {
        let payload = AssignmentPayload(
            id: assignment.id,
            thing_id: assignment.thingId,
            user_id: assignment.userId,
            role: assignment.role,
            created_at: assignment.createdAt,
            updated_at: assignment.updatedAt,
            version: assignment.version,
            updated_by: assignment.updatedBy,
            deleted_at: assignment.deletedAt
        )

        try await client
            .from("assignments")
            .upsert(payload)
            .execute()
    }
}
