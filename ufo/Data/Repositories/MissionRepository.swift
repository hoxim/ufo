//
//  MissionRepository.swift
//  ufo
//
//  Created by Marcin Ryzko on 22/02/2026.
//

import Foundation
import Supabase

@MainActor
final class MissionRepository {

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    /// Pobiera misję po ID z Supabase
    func fetchMission(id: UUID) async throws -> MissionDTO? {
        let mission: MissionDTO? = try await client
            .from("missions")
            .select("*")
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return mission
    }

    /// Aktualizuje misję w Supabase (lub tworzy, jeśli nie istnieje)
    func updateMission(_ mission: Mission) async throws {
        struct Payload: Encodable {
            let id: UUID
            let space_id: UUID
            let title: String
            let description: String
            let difficulty: Int
            let is_completed: Bool
            let version: Int
            let last_updated_at: Date
        }

        let payload = Payload(
            id: mission.id,
            space_id: mission.spaceId,
            title: mission.title,
            description: mission.missionDescription,
            difficulty: mission.difficulty,
            is_completed: mission.isCompleted,
            version: mission.version,
            last_updated_at: mission.lastUpdatedAt
        )

        // Wstaw lub zaktualizuj
        try await client
            .from("missions")
            .upsert(payload)
            .execute()
    }
}
