//
//  SummaryView.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import SwiftUI

enum UFOPath: Hashable {
    case missionDetail(Mission)
    case spaceSettings
    case userProfile
}

struct SummaryView: View {
    @State private var navPath: [UFOPath] = []
    
    var body: some View {
        NavigationStack(path: $navPath) {
            List {
                Section("Your Missions") {
                    Button("Go to Mars Mission") {

                    }
                }
            }
            .navigationTitle("UFO Summary")
            .navigationDestination(for: UFOPath.self) { path in
                switch path {
                case .missionDetail(let mission):
                    Text("Mission Details for: \(mission.title)")
                case .spaceSettings:
                    Text("Space Settings View")
                case .userProfile:
                    Text("User Profile View")
                }
            }
        }
    }
}
