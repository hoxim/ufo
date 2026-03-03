//
//  TabMenuView.swift
//  ufo
//
//  Created by Marcin Ryzko on 10/02/2026.
//

import SwiftUI

struct TabMenuView: View {
    @Binding var selectedTab: TabItem

    var body: some View {
        #if os(iOS)
        TabView(selection: $selectedTab) {
            HomeHubView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(TabItem.home)
            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.bar") }
                .tag(TabItem.budget)
            PeopleHubView()
                .tabItem { Label("People", systemImage: "person.2") }
                .tag(TabItem.people)
            SpaceListView()
                .tabItem { Label("Spaces", systemImage: "person.3") }
                .tag(TabItem.spaces)
        }
        #else
        TabView(selection: $selectedTab) {
            HomeHubView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(TabItem.home)
            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.bar") }
                .tag(TabItem.budget)
            PeopleHubView()
                .tabItem { Label("People", systemImage: "person.2") }
                .tag(TabItem.people)
            SpaceListView()
                .tabItem { Label("Spaces", systemImage: "person.3") }
                .tag(TabItem.spaces)
        }
        #endif
    }
}
