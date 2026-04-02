#if os(watchOS)
import SwiftUI

@main
struct ufoWatch_Watch_App: App {
    @State private var appModel = WatchAppModel()

    var body: some Scene {
        WindowGroup {
            WatchAppRootView()
                .environment(appModel)
        }
    }
}

#endif
