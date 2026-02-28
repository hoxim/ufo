//
//  SpaceListView.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import SwiftUI

struct SpaceListView: View {
    @Environment(AuthRepository.self) private var authRepo
    @Environment(SpaceRepository.self) private var spaceRepo
    
    @State private var spaceToEdit: Space?
    @State private var spaceToInvite: Space?
    @State private var isShowingCreator = false
    
    var body: some View {
        NavigationStack {
            List {
                if let user = authRepo.currentUser {
                    if user.memberships.isEmpty {
                         ContentUnavailableView("spaces.list.empty.title", systemImage: "person.3.slash", description: Text("spaces.list.empty.body"))
                    } else {
                        ForEach(user.memberships) { membership in
                            if let space = membership.space {
                                SpaceRow(space: space, role: membership.role)
                                    .swipeActions(edge: .trailing) {
                                        if membership.role == "admin" {
                                            // if you are owner of the space
                                            Button("spaces.list.delete", role: .destructive) {
                                                // Task { try? await spaceRepo.deleteSpace(space.id) }
                                            }
                                        } else {
                                            // If you were invited
                                            Button("spaces.list.leave", role: .destructive) {
                                                Task { try? await spaceRepo.leaveSpace(spaceId: space.id) }
                                            }
                                        }
                                        
                                        // both can change
                                        if membership.role == "admin" {
                                            Button("spaces.list.edit") {
                                                spaceToEdit = space
                                            }
                                            .tint(.blue)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("spaces.list.title")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingCreator = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // Sheet for new space creation
            .sheet(isPresented: $isShowingCreator) {
                SpaceEditorView()
            }
            // Sheet for space edition
            .sheet(item: $spaceToEdit) { space in
                SpaceEditorView(space: space)
            }
            // Sheet for invitations
            .sheet(item: $spaceToInvite) { space in
                InviteMemberView(spaceId: space.id)
                    .presentationDetents([.medium])
            }
        }
    }
}

struct SpaceRow: View {
    let space: Space
    let role: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(space.name)
                    .font(.headline)
                Text(space.inviteCode)
                    .font(.caption)
                    .monospaced()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(role.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(role == "admin" ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .foregroundStyle(role == "admin" ? .blue : .primary)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
            } label: {
                Label("spaces.list.invite", systemImage: "envelope")
            }
        }
    }
}
