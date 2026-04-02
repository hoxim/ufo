#if os(iOS)

//
//  PhoneSummaryScreen.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import SwiftUI

enum PhoneSummaryPath: Hashable {
    case missionDetail(Mission)
    case spaceSettings
    case userProfile
}

struct PhoneSummaryScreen: View {
    @State private var navPath: [PhoneSummaryPath] = []
    
    var body: some View {
        NavigationStack(path: $navPath) {
            List {
                Section("summary.view.section.missions") {
                    Button("summary.view.action.goToMission") {

                    }
                }
            }
            .navigationTitle("summary.view.title")
            .navigationDestination(for: PhoneSummaryPath.self) { path in
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
    PhoneSummaryScreen()
}

#endif
