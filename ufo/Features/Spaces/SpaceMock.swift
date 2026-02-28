//
//  SpaceMock.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import Foundation
import SwiftData

@MainActor
struct SpaceMock {
    static func makeSampleData(context: ModelContext) -> [Space] {
        let profile = UserProfile(id: UUID(), email: "marcin@hoxim.com", fullName: "Commander Marcin")
        context.insert(profile)
        
        let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
        context.insert(space)
        
        let membership = SpaceMembership(user: profile, space: space, role: "admin")
        context.insert(membership)

        let invite = SpaceInvitation(
            id: UUID(),
            spaceID: UUID(),
            inviterID: UUID(),
            inviteeEmail: "m.ryzko@gmail.com",
            status: "pending",
            spaceName: space.name
        )
        
        context.insert(invite)
        return [space]
    }
}
