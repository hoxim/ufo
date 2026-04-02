#if os(macOS)

//
//  MacSummaryScreen.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import SwiftUI

enum MacSummaryPath: Hashable {
    case missionDetail(Mission)
    case spaceSettings
    case userProfile
}

struct MacSummaryScreen: View {
    @State private var navPath: [MacSummaryPath] = []
    
    var body: some View {
        NavigationStack(path: $navPath) {
            List {
                Section("summary.view.section.missions") {
                    Button("summary.view.action.goToMission") {

                    }
                }
            }
            .navigationTitle("summary.view.title")
            .navigationDestination(for: MacSummaryPath.self) { path in
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

#Preview("Summary") {
    MacSummaryScreen()
}

#endif
