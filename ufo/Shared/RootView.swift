//
//  RootView.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AuthStore.self) private var authStore
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
                AuthView()
            } else if let user = authStore.currentUser, !user.memberships.isEmpty {
                if let selectedSpace = spaceRepository.selectedSpace {
                    mainNavigationLayout
                        .transition(.opacity)
                        .environment(\.selectedSpaceID, selectedSpace.id)
                } else {
                    SpaceSelectorView(userSpaces: user.memberships.compactMap { $0.space })
                        .transition(.move(edge: .leading))
                }
            } else {
                NoSpaceView(spaceRepository: spaceRepository)
            }

            // Invitation alert
            if let invite = spaceRepository.pendingInvitation {
                InvitationAlertView(invite: invite, spaceRepo: spaceRepository)
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
            await notificationStore.bootstrap(spaceId: spaceRepository.selectedSpace?.id)
            await startBackgroundSync()
        }
        .onChange(of: spaceRepository.selectedSpace?.id) { _, newValue in
            notificationStore.setSpace(newValue)
        }
    }

    // MARK: - Layout
    @ViewBuilder
    private var mainNavigationLayout: some View {
        #if os(macOS)
        SidebarMenuView(selectedTab: $selectedTab)
        #else
        TabMenuView(selectedTab: $selectedTab)
        #endif
    }

    /// Handles start background sync.
    private func startBackgroundSync() async {
        guard appPreferences.supportsCloudFeatures else { return }

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
    case home, people, spaces

    var title: String {
        switch self {
        case .home:
            return "Home"
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
        case .people:
            return "person.2"
        case .spaces:
            return "person.3"
        }
    }
}

#Preview {
    RootViewPreview()
}

private struct RootViewPreview: View {
    private let preview = MainNavigationPreviewFactory.make()

    var body: some View {
        RootView()
            .environment(preview.authRepository)
            .environment(preview.spaceRepository)
            .environment(preview.authStore)
            .environment(preview.notificationStore)
            .modelContainer(preview.container)
            #if os(macOS)
            .frame(width: 1000, height: 700)
            #endif
    }
}
