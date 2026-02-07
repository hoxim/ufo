//
//  User.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import Foundation

struct User {
    let id: UUID
    let email: String
    var displayName: String
    var role: String
    var avatarURL: String
    var groupId: UUID?
}
