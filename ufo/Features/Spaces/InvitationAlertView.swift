//
//  InvitationAlertView.swift
//  ufo
//
//  Created by Marcin Ryzko on 10/02/2026.
//

import SwiftUI

struct InvitationAlertView: View {
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
                    Text("Incoming Transmission")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                    
                    Text("Join \(invite.spaceName)?")
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
                            Text("Accept & Join")
                                .bold()
        
                        }.ufoPrimaryButton()
                        
                        // Declione button
                        Button {
                            reject()
                        } label: {
                            Text("Decline")
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
    
    private func accept() {
        isProcessing = true
        Task {
            do {
                try await spaceRepo.acceptInvitation(invite)
            } catch {
                await MainActor.run {
                    isProcessing = false
                    Log.error("Failed to accept invitation: \(error)")
                }
            }
        }
    }
    
    private func reject() {
        isProcessing = true
        Task {
            try? await spaceRepo.rejectInvitation(invite)
        }
    }
    
    private func dismiss() {
        // rseting the variable -> this view closes
        spaceRepo.pendingInvitation = nil
    }
}

#Preview("Light mode") {
    let invite = SpaceInvitation(
        id: UUID(),
        spaceID: UUID(),
        inviterID: UUID(),
        inviteeEmail: "mr@hoxim.com",
        status: "pending",
        receivedAt: .now,
        spaceName: "My space"
    )
    let repo = SpaceRepository(client: SupabaseConfig.client)
    
    InvitationAlertView(invite: invite, spaceRepo: repo)
}

#Preview("Dark mode") {
    let invite = SpaceInvitation(
        id: UUID(),
        spaceID: UUID(),
        inviterID: UUID(),
        inviteeEmail: "mr@hoxim.com",
        status: "pending",
        receivedAt: .now,
        spaceName: "My space"
    )
    let repo = SpaceRepository(client: SupabaseConfig.client)
    
    InvitationAlertView(invite: invite, spaceRepo: repo)
        .preferredColorScheme(.dark)
}
