//
//  RootView.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import SwiftUI

struct RootView: View {
    @Environment(AuthRepository.self) private var authRepository
    @Environment(GroupRepository.self) private var groupRepository

    var body: some View {
        ZStack {
            if authRepository.isLoggedIn {
                // Use the new Many-to-Many logic
                if let user = authRepository.currentUser, !user.memberships.isEmpty {
                    Text("Summary View Placeholder") // Replace with SummaryView()
                } else {
                    NoGroupView(groupRepository: groupRepository)
                }
            } else {
                AuthView()
            }
            
            if let invite = groupRepository.pendingInvitation {
                InvitationOverlay(invite: invite, repo: groupRepository)
            }
        }
        .task {
            if authRepository.isLoggedIn, let email = authRepository.currentUser?.email {
                try? await groupRepository.checkInvites(for: email)
            }
        }
    }
}
