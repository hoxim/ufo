//
//  SpaceListSupport.swift
//  ufo
//
//  Created by Codex on 22/03/2026.
//

import Foundation

enum SpaceFilter: String, CaseIterable, Identifiable {
    case all
    case shared
    case `private`

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Wszystkie"
        case .shared:
            return "Wspólne"
        case .private:
            return "Prywatne"
        }
    }
}

enum SpacePendingAction: Identifiable {
    case delete(Space, String)
    case leave(Space, String)

    var id: UUID {
        switch self {
        case .delete(let space, _), .leave(let space, _):
            return space.id
        }
    }

    var title: String {
        switch self {
        case .delete(let space, _):
            return "Usunąć grupę \(space.name)?"
        case .leave(let space, _):
            return "Opuścić grupę \(space.name)?"
        }
    }

    var message: String {
        switch self {
        case .delete:
            return "Ta operacja usunie całą przestrzeń dla wszystkich członków."
        case .leave:
            return "Po opuszczeniu grupy stracisz dostęp do jej danych, dopóki ktoś nie zaprosi Cię ponownie."
        }
    }

    var confirmTitle: String {
        switch self {
        case .delete:
            return "Usuń"
        case .leave:
            return "Opuść"
        }
    }
}
