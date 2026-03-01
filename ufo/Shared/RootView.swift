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
    
    @State private var selectedTab: TabItem = .missions
    
    // Obsługa arkuszy (sheets)
    @State private var showInviteSheet = false
    @State private var showProfileSheet = false
    @State private var showSettingsSheet = false

    private var canInviteInSelectedSpace: Bool {
        guard
            let user = authStore.currentUser,
            let selectedSpace = spaceRepository.selectedSpace,
            selectedSpace.allowsInvitations
        else {
            return false
        }

        return user.memberships.contains {
            $0.space?.id == selectedSpace.id && $0.role == "admin"
        }
    }

    var body: some View {
        ZStack {
            if authStore.state == .checkingSession || authStore.state == .bootstrapping {
                ProgressView("Przygotowuję dane konta...")
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
            if authStore.state == .checkingSession {
                await authStore.bootstrap()
            }
            await startBackgroundSync()
        }
        .sheet(isPresented: $showInviteSheet) {
            if let selectedSpace = spaceRepository.selectedSpace {
                InviteMemberView(space: selectedSpace)
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            UserProfileView()
                #if os(macOS)
                .frame(minWidth: 480, minHeight: 560)
                #endif
        }
        .sheet(isPresented: $showSettingsSheet) {
            AppSettingsView()
                #if os(macOS)
                .frame(minWidth: 480, minHeight: 560)
                #endif
        }
    }

    // MARK: - Layout Switcher
    @ViewBuilder
    private var mainNavigationLayout: some View {
        #if os(macOS)
        SidebarMenuView(selectedTab: $selectedTab, profileMenu: AnyView(profileMenuButton))
        #else
        TabMenuView(selectedTab: $selectedTab, profileMenu: AnyView(profileMenuButton))
        #endif
    }

    // MARK: - Shared Components
    private var profileMenuButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            UserAvatarView(
                user: authStore.currentUser,
                onSettings: { showSettingsSheet = true },
                onProfile: { showProfileSheet = true },
                onLogout: { Task { await authStore.signOut() } }
            )
            #if os(macOS)
            if let selectedSpace = spaceRepository.selectedSpace, !selectedSpace.allowsInvitations {
                Text("Private Space: utwórz Shared, aby zapraszać.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if !canInviteInSelectedSpace {
                Text("Tylko administrator może zapraszać.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    showInviteSheet = true
                } label: {
                    Label("Invite to Space", systemImage: "envelope")
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            #endif
        }
    }

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

// MARK: - Shared Models
enum TabItem: Hashable {
    case missions, incidents, links, budget, lists, locations, messages, profile, spaces
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
    
    return RootView()
        .environment(authRepo)
        .environment(spaceRepo)
        .environment(authStore)
        #if os(macOS)
        .frame(width: 1000, height: 700)
        #endif
}
