//
//  TabMenuView.swift
//  ufo
//
//  Created by Marcin Ryzko on 10/02/2026.
//

import SwiftUI
import SwiftData

struct TabMenuView: View {
    @Binding var selectedTab: TabItem

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeHubView()
            }
                .tabItem { Label("main.tabs.home", systemImage: "house") }
                .tag(TabItem.home)

            NavigationStack {
                PeopleHubView()
            }
                .tabItem { Label("main.tabs.people", systemImage: "person.2") }
                .tag(TabItem.people)

            NavigationStack {
                SpaceListView()
            }
                .tabItem { Label("main.tabs.spaces", systemImage: "person.3") }
                .tag(TabItem.spaces)
        }
    }
}

#Preview("Tab Menu") {
    @Previewable @State var selectedTab: TabItem = .home
    let preview = MainNavigationPreviewFactory.make()

    return TabMenuView(selectedTab: $selectedTab)
        .environment(preview.authRepository)
        .environment(preview.spaceRepository)
        .environment(preview.authStore)
        .environment(preview.notificationStore)
        .environment(AppPreferences.shared)
        .modelContainer(preview.container)
}
