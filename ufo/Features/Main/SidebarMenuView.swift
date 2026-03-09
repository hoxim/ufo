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

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("main.sidebar.main") {
                    Label("main.tabs.home", systemImage: "house").tag(TabItem.home)
                    Label("main.tabs.people", systemImage: "person.2").tag(TabItem.people)
                }
                Section("main.sidebar.workspace") {
                    Label("main.tabs.spaces", systemImage: "person.3").tag(TabItem.spaces)
                }
            }
            .navigationTitle("main.sidebar.title")
        } detail: {
            NavigationStack {
                detailView(for: selectedTab)
            }
        }
    }

    @ViewBuilder
    /// Handles detail view.
    private func detailView(for tab: TabItem) -> some View {
        switch tab {
            case .home: HomeHubView()
            case .people: PeopleHubView()
            case .spaces: SpaceListView()
        }
    }
}

#endif 
