//
//  InvitationOverlay.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import SwiftUI

struct InvitationOverlay: View {
    let invite: GroupInvitation
    let repo: GroupRepository
    
    var body: some View {
        ZStack {
            // Rozmycie tła, aby skupić uwagę na zaproszeniu
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
            
            VStack(spacing: 24) {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 8) {
                    Text("Nowa Misja Czeka!")
                        .font(.title2.bold())
                    
                    Text("Zostałeś zaproszony do dołączenia do grupy rodzinnej.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                HStack(spacing: 16) {
                    Button("Odrzuć") {
                        Task { try? await repo.rejectInvitation(invite) }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    
                    Button("Akceptuj i wejdź na pokład") {
                        Task { try? await repo.acceptInvitation(invite) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 25).fill(Color.ufoBackground)
            )
            .shadow(radius: 20)
            .padding(24)
        }
    }
}
