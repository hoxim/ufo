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
                Section("summary.view.section.missions") {
                    Button("summary.view.action.goToMission") {

                    }
                }
            }
            .navigationTitle("summary.view.title")
            .navigationDestination(for: UFOPath.self) { path in
                switch path {
                case .missionDetail(let mission):
                    Text("\(String(localized: "summary.view.missionDetails.prefix")) \(mission.title)")
                case .spaceSettings:
                    Text("summary.view.spaceSettings")
                case .userProfile:
                    Text("summary.view.userProfile")
                }
            }
        }
    }
}
