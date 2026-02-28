//
//  MissionsListView.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import SwiftUI
import SwiftData

struct MissionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    
    @Query(sort: \Mission.createdAt, order: .reverse) private var missions: [Mission]
    @State private var isAddingMission = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(missions) { mission in
                    HStack {
                        Image(systemName: mission.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(mission.isCompleted ? .green : .gray)
                            .onTapGesture { toggleMission(mission) }
                        
                        VStack(alignment: .leading) {
                            Text(mission.title).font(.headline)
                            if !mission.missionDescription.isEmpty {
                                Text(mission.missionDescription).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        // Difficulty icon
                        HStack(spacing: 2) {
                            ForEach(0..<mission.difficulty, id: \.self) { _ in
                                Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Active Missions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isAddingMission = true }) {
                        Label("Add Mission", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingMission) {
                AddMissionView()
                    .presentationDetents([.medium])
            }
        }
    }

    private func toggleMission(_ mission: Mission) {
        mission.isCompleted.toggle()
        // SwiftData (autosave)
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(missions[index])
            }
        }
    }
}

struct AddMissionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SpaceRepository.self) private var spaceRepo
    
    @State private var title = ""
    @State private var desc = ""
    @State private var difficulty = 1
    
    var body: some View {
        Form {
            TextField("Mission Title", text: $title)
            TextField("Briefing (Desc)", text: $desc)
            Stepper("Difficulty: \(difficulty)", value: $difficulty, in: 1...5)
            
            Button("Deploy Mission") {
                addMission()
            }
            .disabled(title.isEmpty)
        }
        .disabled(spaceRepo.selectedSpace == nil || title.isEmpty)
    }
    
    private func addMission() {
        guard let spaceID = spaceRepo.selectedSpace?.id else {
            Log.error("Attempted to add mission without selected space")
            return
        }
        
        let newMission = Mission(
            spaceId: spaceID, // TODO: Podmienić na realne ID grupy
            title: title,
            missionDescription: desc,
            difficulty: difficulty
        )
        modelContext.insert(newMission)
        dismiss()
        
    }
}
