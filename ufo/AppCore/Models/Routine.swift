import Foundation
import SwiftData

@Model
final class Routine {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var title: String
    var category: String
    var personName: String?
    var notes: String?
    var startMinuteOfDay: Int
    var durationMinutes: Int
    var activeWeekdaysRaw: String
    var createdAt: Date
    var updatedAt: Date
    var createdBy: UUID?
    var updatedBy: UUID?
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        spaceId: UUID,
        title: String,
        category: String = RoutineCategory.other.rawValue,
        personName: String? = nil,
        notes: String? = nil,
        startMinuteOfDay: Int,
        durationMinutes: Int = 30,
        activeWeekdays: [Int] = Array(1...7),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        createdBy: UUID? = nil,
        updatedBy: UUID? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.title = title
        self.category = category
        self.personName = personName
        self.notes = notes
        self.startMinuteOfDay = startMinuteOfDay
        self.durationMinutes = durationMinutes
        self.activeWeekdaysRaw = activeWeekdays.map(String.init).joined(separator: ",")
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.updatedBy = updatedBy
        self.deletedAt = deletedAt
    }
}

enum RoutineCategory: String, CaseIterable, Identifiable {
    case food
    case sleep
    case diaper
    case medicine
    case training
    case hygiene
    case school
    case home
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .food: "Posiłki"
        case .sleep: "Sen"
        case .diaper: "Pieluchy"
        case .medicine: "Leki"
        case .training: "Trening"
        case .hygiene: "Higiena"
        case .school: "Szkoła"
        case .home: "Dom"
        case .other: "Inne"
        }
    }

    var iconName: String {
        switch self {
        case .food: "fork.knife"
        case .sleep: "bed.double.fill"
        case .diaper: "figure.and.child.holdinghands"
        case .medicine: "pills.fill"
        case .training: "figure.run"
        case .hygiene: "drop.fill"
        case .school: "backpack.fill"
        case .home: "house.fill"
        case .other: "clock.fill"
        }
    }
}

extension Routine {
    var categoryValue: RoutineCategory {
        RoutineCategory(rawValue: category) ?? .other
    }

    var activeWeekdays: [Int] {
        activeWeekdaysRaw
            .split(separator: ",")
            .compactMap { Int($0) }
            .filter { (1...7).contains($0) }
    }

    var endMinuteOfDay: Int {
        startMinuteOfDay + durationMinutes
    }

    func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
        activeWeekdays.contains(calendar.component(.weekday, from: date))
    }
}
