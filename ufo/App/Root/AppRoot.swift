import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct AppRoot: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(DeviceSessionStore.self) private var deviceSessionStore
    @Environment(SpaceRepository.self) private var spaceRepository
    @Environment(AppNotificationStore.self) private var notificationStore
    @Environment(AppPreferences.self) private var appPreferences
    
    @State private var selectedTab: TabItem = .home
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    var body: some View {
        ZStack {
            if authStore.state == .checkingSession || authStore.state == .bootstrapping {
                StartupLoadingView()
            } else if authStore.state == .signedOut {
                authScreen
            } else if let user = authStore.currentUser, !user.memberships.isEmpty {
                if let selectedSpace = spaceRepository.selectedSpace {
                    mainNavigationLayout
                        .transition(.opacity)
                        .environment(\.selectedSpaceID, selectedSpace.id)
                } else {
                    spaceSelectorScreen(userSpaces: user.memberships.compactMap { $0.space })
                        .transition(.move(edge: .leading))
                }
            } else {
                noSpaceScreen
            }

            // Invitation alert
            if let invite = spaceRepository.pendingInvitation {
                platformInvitationAlert(invite: invite)
                    .zIndex(100)
                    .transition(.opacity.combined(with: .scale))
            }

            if let toast = notificationStore.activeToast {
                ToastOverlay(toast: toast) {
                    notificationStore.dismissToast()
                }
                .zIndex(200)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.default, value: authStore.state)
        .animation(.easeInOut, value: spaceRepository.selectedSpace)
        .animation(.spring(), value: spaceRepository.pendingInvitation)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: notificationStore.activeToast)
        .task {
            guard !isPreview else { return }
            if authStore.state == .checkingSession {
                await authStore.bootstrap()
            }
            if authStore.state == .ready {
                await deviceSessionStore.bootstrap(context: CurrentDeviceContext.make())
            } else if authStore.state == .signedOut {
                deviceSessionStore.reset()
            }
            await notificationStore.bootstrap(spaceId: spaceRepository.selectedSpace?.id)
            await startBackgroundSync()
        }
        .onChange(of: spaceRepository.selectedSpace?.id) { _, newValue in
            notificationStore.setSpace(newValue)
        }
        .onChange(of: authStore.state) { _, newValue in
            Task {
                if newValue == .ready {
                    await deviceSessionStore.bootstrap(context: CurrentDeviceContext.make())
                } else if newValue == .signedOut {
                    deviceSessionStore.reset()
                }
            }
        }
    }

    // MARK: - Layout
    @ViewBuilder
    private var mainNavigationLayout: some View {
        #if os(macOS)
        MacAppShell(selectedTab: $selectedTab)
        #elseif os(iOS)
        if isPadInterface {
            PadAppShell(selectedTab: $selectedTab)
        } else {
            PhoneAppShell(selectedTab: $selectedTab)
        }
        #else
        PhoneAppShell(selectedTab: $selectedTab)
        #endif
    }

    @ViewBuilder
    private var authScreen: some View {
        #if os(macOS)
        MacAuthScreen()
        #elseif os(iOS)
        if isPadInterface {
            PadAuthScreen()
        } else {
            PhoneAuthScreen()
        }
        #else
        PhoneAuthScreen()
        #endif
    }

    @ViewBuilder
    private func spaceSelectorScreen(userSpaces: [Space]) -> some View {
        #if os(macOS)
        MacSpaceSelectorScreen(userSpaces: userSpaces)
        #elseif os(iOS)
        if isPadInterface {
            PadSpaceSelectorScreen(userSpaces: userSpaces)
        } else {
            PhoneSpaceSelectorScreen(userSpaces: userSpaces)
        }
        #else
        PhoneSpaceSelectorScreen(userSpaces: userSpaces)
        #endif
    }

    @ViewBuilder
    private var noSpaceScreen: some View {
        #if os(macOS)
        MacNoSpaceScreen(spaceRepository: spaceRepository)
        #elseif os(iOS)
        if isPadInterface {
            PadNoSpaceScreen(spaceRepository: spaceRepository)
        } else {
            PhoneNoSpaceScreen(spaceRepository: spaceRepository)
        }
        #else
        PhoneNoSpaceScreen(spaceRepository: spaceRepository)
        #endif
    }

    private var isPadInterface: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    @ViewBuilder
    private func platformInvitationAlert(invite: SpaceInvitation) -> some View {
        #if os(macOS)
        MacInvitationAlertView(invite: invite, spaceRepo: spaceRepository)
        #elseif os(iOS)
        if isPadInterface {
            PadInvitationAlertView(invite: invite, spaceRepo: spaceRepository)
        } else {
            PhoneInvitationAlertView(invite: invite, spaceRepo: spaceRepository)
        }
        #else
        EmptyView()
        #endif
    }

    /// Handles start background sync.
    private func startBackgroundSync() async {
        guard appPreferences.supportsCloudFeatures else { return }
        var deviceRefreshTick = 0

        while !authStore.isLoggedIn {
            try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        }
        
        while !Task.isCancelled {
            if let user = authStore.currentUser {
                try? await spaceRepository.checkInvites(for: user.email)
                
                if !user.memberships.isEmpty && spaceRepository.selectedSpace == nil {
                    let spaces = user.memberships.compactMap { $0.space }
                    spaceRepository.restoreLastSelectedSpace(from: spaces)
                }
            }

            deviceRefreshTick += 1
            if deviceRefreshTick >= 12 {
                deviceRefreshTick = 0
                await deviceSessionStore.refreshDevices()
            }
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
        }
    }
}

private struct StartupLoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.blue.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text("ufo")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                ProgressView("root.loading.account")
                    .tint(.white)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding()
        }
    }
}

// MARK: - Shared Models
enum TabItem: Hashable, CaseIterable {
    case home, search, people, spaces

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .search:
            return "Szukaj"
        case .people:
            return "People"
        case .spaces:
            return "Spaces"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house"
        case .search:
            return "magnifyingglass"
        case .people:
            return "person.2"
        case .spaces:
            return "person.3"
        }
    }
}

#Preview {
    AppRootPreview()
}

private struct AppRootPreview: View {
    private let preview = MainNavigationPreviewFactory.make()

    var body: some View {
        AppRoot()
            .environment(preview.authRepository)
            .environment(preview.spaceRepository)
            .environment(preview.authStore)
            .environment(DeviceSessionStore(repository: DeviceSessionRepository(client: SupabaseConfig.client), authRepository: preview.authRepository))
            .environment(preview.notificationStore)
            .environment(AppPreferences.shared)
            .modelContainer(preview.container)
            #if os(macOS)
            .frame(width: 1000, height: 700)
            #endif
    }
}
