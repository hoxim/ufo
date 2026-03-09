//
//  InvitationAlertView.swift
//  ufo
//
//  Created by Marcin Ryzko on 10/02/2026.
//

import SwiftUI

struct InvitationAlertView: View {
    @Environment(AuthStore.self) private var authStore
    let invite: SpaceInvitation
    var spaceRepo: SpaceRepository
    
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            Color.backgroundSolid.ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            Card {
                // icon
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 50))
                    .frame(width: 100, height: 100)
                    .frame(maxWidth: .infinity)
                
                VStack() {
                    Text("spaces.invitation.title")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                    
                    Text(String(format: String(localized: "spaces.invitation.joinQuestion"), invite.spaceName))
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .bold()
                        
                }.padding(24)
                
                if isProcessing {
                    ProgressView()
                        .padding()
                } else {
                    VStack(spacing: 12) {
                        // Accept button
                        Button {
                            accept()
                        } label: {
                            Text("spaces.invitation.accept")
                                .bold()
        
                        }.ufoPrimaryButton()
                        
                        // Declione button
                        Button {
                            reject()
                        } label: {
                            Text("spaces.invitation.decline")
                        }.ufoDestructiveButton()

                    }
                    .padding(.bottom, 24)
                }
            }
            .cornerRadius(24)
            .shadow(radius: 4)
            .frame(maxWidth: 320)
            .padding()
        }
    }
    
    /// Handles accept.
    private func accept() {
        isProcessing = true
        Task {
            do {
                try await spaceRepo.acceptInvitation(invite)
                await authStore.refreshProfileAndSpaces()
            } catch {
                await MainActor.run {
                    isProcessing = false
                    Log.error("Failed to accept invitation: \(error)")
                }
            }
        }
    }
    
    /// Handles reject.
    private func reject() {
        isProcessing = true
        Task {
            try? await spaceRepo.rejectInvitation(invite)
        }
    }
    
    /// Handles dismiss.
    private func dismiss() {
        // rseting the variable -> this view closes
        spaceRepo.pendingInvitation = nil
    }
}

#Preview("Light mode") {
    let invite = SpaceInvitation(
        id: UUID(),
        spaceId: UUID(),
        inviterId: UUID(),
        inviteeEmail: "mr@hoxim.com",
        inviteCode: "ABC123",
        status: "pending",
        sentAt: .now,
        spaceName: "My space"
    )
    let repo = SpaceRepository(client: SupabaseConfig.client)
    
    InvitationAlertView(invite: invite, spaceRepo: repo)
        .environment(AuthStore(authRepository: AuthRepository(client: SupabaseConfig.client), spaceRepository: repo))
}

#Preview("Dark mode") {
    let invite = SpaceInvitation(
        id: UUID(),
        spaceId: UUID(),
        inviterId: UUID(),
        inviteeEmail: "mr@hoxim.com",
        inviteCode: "ABC123",
        status: "pending",
        sentAt: .now,
        spaceName: "My space"
    )
    let repo = SpaceRepository(client: SupabaseConfig.client)
    
    InvitationAlertView(invite: invite, spaceRepo: repo)
        .environment(AuthStore(authRepository: AuthRepository(client: SupabaseConfig.client), spaceRepository: repo))
        .preferredColorScheme(.dark)
}
