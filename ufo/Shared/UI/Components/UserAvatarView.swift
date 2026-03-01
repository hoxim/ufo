//
//  UserProfileView.swift
//  ufo
//
//  Created by Marcin Ryzko on 19/02/2026.
//

// ufo/Shared/Components/UserAvatarView.swift

import SwiftUI

struct UserAvatarView: View {
    let user: UserProfile?
    var onSettings: () -> Void
    var onProfile: () -> Void
    var onLogout: () -> Void
    
    var body: some View {
        Menu {
            Section(user?.email ?? "User") {
                Button(action: onProfile) {
                    Label("Profile Settings", systemImage: "person.crop.circle")
                }
                Button(action: onSettings) {
                    Label("App Settings", systemImage: "gearshape")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: onLogout) {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            HStack(spacing: 10) {
                if let urlString = user?.avatarURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Image(systemName: "person.circle.fill") // Fallback
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                } else {
                    Circle()
                        .fill(Color.accentColor.gradient)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text(user?.fullName?.prefix(1) ?? "U")
                                .foregroundStyle(.white)
                                .fontWeight(.bold)
                        }
                }
                #if os(macOS)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user?.fullName ?? "Unknown Scout")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(user?.role.capitalized ?? "User")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                #else
                Text(user?.fullName ?? "Unknown Scout")
                    .font(.subheadline)
                #endif
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    let mockUser = UserProfile(
        id: UUID(),
        email: "marcin@ufo.pl",
        fullName: "Marcin Ryzko",
        role: "Commander"
    )

    UserAvatarView(
        user: mockUser,
        onSettings: { print("Settings tapped") },
        onProfile: { print("Profile tapped") },
        onLogout: { print("Logout tapped") }
    )
    .padding()
    #if os(macOS)
    .frame(width: 250) // Symulujemy szerokość sidebaru na Macu
    #endif
}
