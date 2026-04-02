import SwiftUI

#if os(macOS)
struct MacAppShell: View {
    @Binding var selectedTab: TabItem

    var body: some View {
        MacSidebarShell(selectedTab: $selectedTab)
    }
}
#endif
