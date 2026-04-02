#if os(iOS)

import SwiftUI
import SwiftData

struct PhoneTabShell: View {
    @Binding var selectedTab: TabItem

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PhoneHomeScreen()
            }
                .tabItem { Label("main.tabs.home", systemImage: "house") }
                .tag(TabItem.home)

            NavigationStack {
                PhoneSearchScreen()
            }
                .tabItem { Label("Szukaj", systemImage: "magnifyingglass") }
                .tag(TabItem.search)

            NavigationStack {
                PhonePeopleScreen()
            }
                .tabItem { Label("main.tabs.people", systemImage: "person.2") }
                .tag(TabItem.people)

            NavigationStack {
                PhoneSpacesScreen()
            }
                .tabItem { Label("main.tabs.spaces", systemImage: "person.3") }
                .tag(TabItem.spaces)
        }
    }
}

#Preview("Tab Menu") {
    @Previewable @State var selectedTab: TabItem = .home
    let preview = MainNavigationPreviewFactory.make()

    return PhoneTabShell(selectedTab: $selectedTab)
        .environment(preview.authRepository)
        .environment(preview.spaceRepository)
        .environment(preview.authStore)
        .environment(preview.notificationStore)
        .environment(AppPreferences.shared)
        .modelContainer(preview.container)
}

#endif
