//
//  UserProfileView.swift
//  ufo
//
//  Created by Marcin Ryzko on 22/02/2026.
//

import SwiftUI

struct UserProfileView: View {
    
    @State var user: UserProfile?
    
    var body: some View {
        Form {
            avatarView
            
            Section("Account") {
                LabeledContent("Name") {
                    Text(user?.fullName ?? "No name")
                        .foregroundStyle(.secondary)
                }
                
                LabeledContent("Avatar URL") {
                    Text(user?.avatarURL ?? "-")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .navigationTitle("Profile")
    }
    
    // MARK: - Avatar
    
    private var avatarView: some View {
        Group {
            if let avatarURL = user?.avatarURL,
               let url = URL(string: avatarURL),
               !avatarURL.isEmpty {
                
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderAvatar
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderAvatar
                    @unknown default:
                        placeholderAvatar
                    }
                }
            } else {
                placeholderAvatar
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        .frame(maxWidth: .infinity)
    }
    
    private var placeholderAvatar: some View {
        Image("default_avatar")
            .resizable()
            .scaledToFill()
    }
}

#Preview {
    UserProfileView()
}
