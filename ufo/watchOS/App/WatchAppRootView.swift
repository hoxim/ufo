#if os(watchOS)
import SwiftUI

struct WatchAppRootView: View {
    @Environment(WatchAppModel.self) private var model

    var body: some View {
        Group {
            switch model.state {
            case .checkingSession, .loadingWorkspace:
                ProgressView("Ładowanie")
            case .signedOut:
                NavigationStack {
                    WatchSignInView()
                }
            case .ready:
                NavigationStack {
                    WatchFeatureMenuView()
                }
            }
        }
        .task {
            guard model.state == .checkingSession else { return }
            await model.bootstrap()
        }
    }
}

#endif
