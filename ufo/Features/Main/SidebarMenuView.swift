//
//  SidebarMenuView.swift
//  ufo
//
//  Created by Marcin Ryzko on 10/02/2026.
//

import SwiftUI

#if os(macOS) 

struct SidebarMenuView: View {
    @Binding var selectedTab: TabItem
    var profileMenu: AnyView

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Operations") {
                    Label("Missions", systemImage: "target").tag(TabItem.missions)
                    Label("Incidents", systemImage: "bolt.horizontal").tag(TabItem.incidents)
                }
                Section("Crew") {
                    Label("Spaces", systemImage: "person.3").tag(TabItem.spaces)
                }
            }
            .navigationTitle("UFO Control")
            .safeAreaInset(edge: .bottom) {
                profileMenu.padding()
            }
        } detail: {
            NavigationStack {
                detailView(for: selectedTab)
            }
        }
    }

    @ViewBuilder
    private func detailView(for tab: TabItem) -> some View {
        switch tab {
            case .missions: MissionsListView()
            case .incidents: IncidentsListView()
            case .spaces, .profile: SpaceListView()
        }
    }
}

#endif 
