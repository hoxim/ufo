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
                    Label("Links", systemImage: "link").tag(TabItem.links)
                    Label("Lists", systemImage: "checklist").tag(TabItem.lists)
                    Label("Budget", systemImage: "chart.bar").tag(TabItem.budget)
                    Label("Map", systemImage: "map").tag(TabItem.locations)
                    Label("Chat", systemImage: "message").tag(TabItem.messages)
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
            case .links: LinksListView()
            case .lists: SharedListsView()
            case .budget: BudgetView()
            case .locations: LocationsView()
            case .messages: MessagesView()
            case .spaces, .profile: SpaceListView()
        }
    }
}

#endif 
