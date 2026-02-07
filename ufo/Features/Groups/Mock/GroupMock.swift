//
//  GroupMock.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import Foundation
import SwiftData

@MainActor
struct GroupMock {
    static func makeSampleData(context: ModelContext) {
        let profile = UserProfile(id: UUID(), email: "marcin@hoxim.com", fullName: "Commander Marcin")
        context.insert(profile)
        
        let group = Group(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
        context.insert(group)
        
        // Fix: Use the correct initializer we defined in models
        let membership = GroupMembership(user: profile, group: group, role: "admin")
        context.insert(membership)
        
        // Fix: GroupInvitation needs (id, group, inviter, email)
        let invitation = GroupInvitation(
            id: UUID(),
            group: group,
            inviter: profile,
            email: "nina@hoxim.com"
        )
        context.insert(invitation)
    }
}
