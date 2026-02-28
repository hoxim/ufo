//
//  RootView.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import SwiftUI

struct RootView: View {
    @Environment(AuthRepository.self) private var authRepository
    @Environment(SpaceRepository.self) private var spaceRepository
    
    @State private var selectedTab: TabItem = .missions
    
    // Obsługa arkuszy (sheets)
    @State private var showInviteSheet = false
    @State private var showProfileSheet = false
    @State private var showSettingsSheet = false

    var body: some View {
        ZStack {
            if authRepository.isLoggedIn {
                if let user = authRepository.currentUser, !user.memberships.isEmpty {
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
            } else {
                AuthView()
            }

            // Invitation alert
            if let invite = spaceRepository.pendingInvitation {
                InvitationAlertView(invite: invite, spaceRepo: spaceRepository)
                    .zIndex(100)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.default, value: authRepository.isLoggedIn)
        .animation(.easeInOut, value: spaceRepository.selectedSpace)
        .animation(.spring(), value: spaceRepository.pendingInvitation)
        .task {
            await startBackgroundSync()
        }
        .sheet(isPresented: $showInviteSheet) {
            if let spaceId = spaceRepository.selectedSpace?.id {
                InviteMemberView(spaceId: spaceId)
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            Text("Profile Settings")
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
        Menu {
            Button { showProfileSheet = true } label: {
                Label("Profile", systemImage: "person.circle")
            }
            Button { showSettingsSheet = true } label: {
                Label("Settings", systemImage: "gear")
            }
            Divider()
            Button { showInviteSheet = true } label: {
                Label("Invite to Space", systemImage: "envelope")
            }
            Button(role: .destructive) {
                Task { await authRepository.signOut() }
            } label: {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(authRepository.currentUser?.fullName?.prefix(1) ?? "U")
                        .foregroundStyle(.white).bold()
                )
        }
    }

    private func startBackgroundSync() async {
        while !authRepository.isLoggedIn {
            try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        }
        
        while !Task.isCancelled {
            if let user = authRepository.currentUser {
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
    case missions, incidents, profile, spaces
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
    
    return RootView()
        .environment(authRepo)
        .environment(spaceRepo)
        #if os(macOS)
        .frame(width: 1000, height: 700)
        #endif
}
