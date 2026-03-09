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
                .tabItem { Label("main.tabs.home", systemImage: "house") }
                .tag(TabItem.home)
            PeopleHubView()
                .tabItem { Label("main.tabs.people", systemImage: "person.2") }
                .tag(TabItem.people)
            SpaceListView()
                .tabItem { Label("main.tabs.spaces", systemImage: "person.3") }
                .tag(TabItem.spaces)
        }
        #else
        TabView(selection: $selectedTab) {
            HomeHubView()
                .tabItem { Label("main.tabs.home", systemImage: "house") }
                .tag(TabItem.home)
            PeopleHubView()
                .tabItem { Label("main.tabs.people", systemImage: "person.2") }
                .tag(TabItem.people)
            SpaceListView()
                .tabItem { Label("main.tabs.spaces", systemImage: "person.3") }
                .tag(TabItem.spaces)
        }
        #endif
    }
}
