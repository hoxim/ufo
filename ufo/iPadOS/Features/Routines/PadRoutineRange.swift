#if os(iOS)

import SwiftUI

enum PadRoutineRange: CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { title }

    var title: String {
        switch self {
        case .day: "Dzień"
        case .week: "Tydzień"
        case .month: "Miesiąc"
        }
    }
}

#endif
