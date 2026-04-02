import SwiftUI

#if os(iOS)
struct PhoneAppShell: View {
    @Binding var selectedTab: TabItem

    var body: some View {
        PhoneTabShell(selectedTab: $selectedTab)
    }
}
#endif
