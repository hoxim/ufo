//
//  TabMenuView.swift
//  ufo
//
//  Created by Marcin Ryzko on 10/02/2026.
//

import SwiftUI

struct TabMenuView: View {
    @Binding var selectedTab: TabItem
    var profileMenu: AnyView

    var body: some View {
        TabView(selection: $selectedTab) {
            MissionsListView()
                .tabItem { Label("Missions", systemImage: "target") }
                .tag(TabItem.missions)
            
            IncidentsListView()
                .tabItem { Label("Incidents", systemImage: "bolt.horizontal") }
                .tag(TabItem.incidents)
            
            SpaceListView()
                .tabItem { Label("Spaces", systemImage: "person.3") }
                .tag(TabItem.spaces)
        }
        .overlay(alignment: .topTrailing) {
            profileMenu.padding()
        }
    }
}
