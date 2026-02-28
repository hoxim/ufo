//
//  Untitled.swift
//  ufo
//
//  Created by Marcin Ryzko on 22/02/2026.
//

import SwiftUI
import Observation
import SwiftData

@Observable
final class MissionStore {

    private let modelContext: ModelContext
    private let missionRepository: MissionRepository   // repozytorium obsługujące Supabase
    var missions: [Mission] = []

    init(modelContext: ModelContext, missionRepository: MissionRepository) {
        self.modelContext = modelContext
        self.missionRepository = missionRepository
        loadLocalMissions()
    }

    // Załaduj wszystko z SwiftData
    @MainActor
    func loadLocalMissions() {
        do {
            missions = try modelContext.fetch(FetchDescriptor<Mission>(sortBy: [SortDescriptor(\.lastUpdatedAt, order: .forward)]))
        } catch {
            print("Failed to fetch missions: \(error)")
            missions = []
        }
    }

    // Dodaj misję lokalnie i oznacz do synchronizacji
    @MainActor
    func addMission(_ mission: Mission) {
        mission.pendingSync = true
        mission.version = max(1, mission.version)
        mission.lastUpdatedAt = .now
        mission.updatedAt = .now
        modelContext.insert(mission)
        missions.append(mission)
    }

    // Aktualizuj misję lokalnie
    @MainActor
    func updateMission(_ mission: Mission, title: String? = nil, description: String? = nil, difficulty: Int? = nil) {
        if let title = title { mission.title = title }
        if let description = description { mission.missionDescription = description }
        if let difficulty = difficulty { mission.difficulty = difficulty }
        mission.pendingSync = true
        mission.version += 1
        mission.lastUpdatedAt = .now
        mission.updatedAt = .now
    }

    // Synchronizacja z Supabase
    @MainActor
    func syncMissions() async {
        for mission in missions.filter({ $0.pendingSync }) {
            do {
                // fetch latest from server
                if let remote = try await missionRepository.fetchMission(id: mission.id) {
                    if remote.version > mission.version {
                        // konflikt: zdalna wersja nowsza
                        // tutaj możesz zrobić merge albo wyświetlić alert
                        print("Conflict detected for mission \(mission.title)")
                        continue
                    }
                }

                // upload / update
                try await missionRepository.updateMission(mission)
                mission.pendingSync = false
            } catch {
                print("Failed to sync mission \(mission.title): \(error)")
            }
        }
    }
}
