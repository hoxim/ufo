#if os(iOS)

import SwiftUI

struct PadTabShell: View {
    @Binding var selectedTab: TabItem

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PadHomeScreen()
            }
            .tabItem { Label("main.tabs.home", systemImage: "house") }
            .tag(TabItem.home)

            NavigationStack {
                PadSearchScreen()
            }
            .tabItem { Label("main.tabs.search", systemImage: "magnifyingglass") }
            .tag(TabItem.search)

            NavigationStack {
                PadPeopleScreen()
            }
            .tabItem { Label("main.tabs.people", systemImage: "person.2") }
            .tag(TabItem.people)

            NavigationStack {
                PadSpacesScreen()
            }
            .tabItem { Label("main.tabs.spaces", systemImage: "person.3") }
            .tag(TabItem.spaces)
        }
    }
}

#endif
