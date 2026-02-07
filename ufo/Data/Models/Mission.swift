//
//  Task.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import Foundation
import SwiftData

@Model
final class Mission {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String?
    var isCompleted: Bool = false
    var dueDate: Date?

    var recurrenceRule: String? // np. "daily", "weekly"

    var group: Group?
    var assignees: [UserProfile] = [] // Wiele osób przypisanych do zadania

    init(id: UUID, title: String, group: Group) {
        self.id = id
        self.title = title
        self.group = group
    }
}
