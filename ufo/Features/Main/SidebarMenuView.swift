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
                Section("Main") {
                    Label("Home", systemImage: "house").tag(TabItem.home)
                    Label("Budget", systemImage: "chart.bar").tag(TabItem.budget)
                    Label("People", systemImage: "person.2").tag(TabItem.people)
                }
                Section("Workspace") {
                    Label("Spaces", systemImage: "person.3").tag(TabItem.spaces)
                }
            }
            .navigationTitle("UFO Control")
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
            case .budget: BudgetView()
            case .people: PeopleHubView()
            case .spaces: SpaceListView()
        }
    }
}

#endif 
