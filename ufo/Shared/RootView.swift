//
//  RootView.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(SpaceRepository.self) private var spaceRepository
    
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
        }
        .animation(.default, value: authStore.state)
        .animation(.easeInOut, value: spaceRepository.selectedSpace)
        .animation(.spring(), value: spaceRepository.pendingInvitation)
        .task {
            guard !isPreview else { return }
            if authStore.state == .checkingSession {
                await authStore.bootstrap()
            }
            await startBackgroundSync()
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
enum TabItem: Hashable {
    case home, people, spaces
}

#Preview {

    let mockUser = UserProfile(
        id: UUID(),
        email: "maciek@ufo.pl",
        fullName: "Maciek Hoxim",
        role: "admin"
    )

    let mockSpace = Space(id: UUID(), name: "Hoxim Squad", inviteCode: "UFO-123")
    let membership = SpaceMembership(user: mockUser, space: mockSpace, role: "admin")
    mockUser.memberships = [membership]
    
    let authRepo = AuthRepository(
        client: SupabaseConfig.client,
        isLoggedIn: true,
        currentUser: mockUser
    )
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = mockSpace
    let authStore = AuthStore(authRepository: authRepo, spaceRepository: spaceRepo)
    authStore.state = .ready
    
    return RootView()
        .environment(authRepo)
        .environment(spaceRepo)
        .environment(authStore)
        #if os(macOS)
        .frame(width: 1000, height: 700)
        #endif
}
