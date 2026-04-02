import SwiftUI

#if os(iOS)
struct PadAppShell: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var selectedTab: TabItem

    var body: some View {
        GeometryReader { proxy in
            Group {
                if prefersSidebarLayout(in: proxy.size) {
                    PadSidebarShell(selectedTab: $selectedTab)
                } else {
                    PadTabShell(selectedTab: $selectedTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func prefersSidebarLayout(in size: CGSize) -> Bool {
        horizontalSizeClass == .regular && size.width > size.height
    }
}
#endif
