#if os(iOS)

import SwiftUI

struct PhoneRoutineWeekView: View {
    let startDate: Date
    let routines: [Routine]
    let logs: [RoutineLog]

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
                let dayRoutines = routines
                    .filter { $0.isActive(on: day, calendar: calendar) }
                    .sorted { $0.startMinuteOfDay < $1.startMinuteOfDay }
                let dayLogs = logs.filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
                let completedRoutineIds = Set(dayLogs.map(\.routineId))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(day.formatted(.dateTime.weekday(.wide)))
                            .font(.headline)
                        Spacer()
                        Text(day.formatted(.dateTime.day().month()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if dayRoutines.isEmpty {
                        Text("routines.period.empty")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 10) {
                            weekPill(title: String(localized: "routines.summary.scheduled"), value: "\(dayRoutines.count)", tint: .blue)
                            weekPill(title: String(localized: "routines.summary.completed"), value: "\(completedRoutineIds.count)", tint: .green)
                            weekPill(title: String(localized: "routines.summary.logs"), value: "\(dayLogs.count)", tint: .orange)
                        }

                        ForEach(dayRoutines.prefix(3)) { routine in
                            HStack(spacing: 10) {
                                Image(systemName: completedRoutineIds.contains(routine.id) ? "checkmark.circle.fill" : routine.categoryValue.iconName)
                                    .foregroundStyle(completedRoutineIds.contains(routine.id) ? .green : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(routine.title)
                                        .font(.subheadline.weight(.medium))

                                    if let personName = routine.personName, !personName.isEmpty {
                                        Text(personName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text(timeLabel(for: routine))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if dayRoutines.count > 3 {
                            Text(String(format: String(localized: "routines.period.more"), dayRoutines.count - 3))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.secondarySystemBackgroundAdaptive, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func timeLabel(for routine: Routine) -> String {
        String(format: "%02d:%02d", routine.startMinuteOfDay / 60, routine.startMinuteOfDay % 60)
    }

    private func weekPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct PhoneRoutineMonthView: View {
    let monthDate: Date
    let routines: [Routine]
    let logs: [RoutineLog]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private var calendar: Calendar { .current }

    var body: some View {
        let interval = calendar.dateInterval(of: .month, for: monthDate) ?? DateInterval(start: monthDate, duration: 60 * 60 * 24 * 30)
        let firstMonthDay = interval.start
        let weekdayOffset = calendar.component(.weekday, from: firstMonthDay) - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                monthLegend(title: String(localized: "routines.summary.scheduled"), tint: .blue)
                monthLegend(title: String(localized: "routines.summary.done"), tint: .green)
                monthLegend(title: String(localized: "routines.summary.partial"), tint: .orange)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<weekdayOffset, id: \.self) { _ in
                    Color.clear.frame(height: 64)
                }

                ForEach(1...daysInMonth, id: \.self) { dayNumber in
                    let day = calendar.date(byAdding: .day, value: dayNumber - 1, to: firstMonthDay) ?? firstMonthDay
                    let scheduled = routines.filter { $0.isActive(on: day, calendar: calendar) }
                    let completed = Set(
                        logs
                            .filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
                            .map(\.routineId)
                    )
                    let completedCount = completed.count
                    let scheduledCount = scheduled.count

                    VStack(spacing: 6) {
                        Text("\(dayNumber)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        if scheduledCount > 0 {
                            Text("\(completedCount)/\(scheduledCount)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        } else {
                            Text(" ")
                                .font(.caption.bold())
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(background(forScheduled: scheduledCount, completed: completedCount))
                }
            }
        }
    }

    private func background(forScheduled scheduledCount: Int, completed completedCount: Int) -> some View {
        let fill: Color

        if scheduledCount == 0 {
            fill = Color.secondarySystemBackgroundAdaptive.opacity(0.45)
        } else if completedCount >= scheduledCount {
            fill = .green.opacity(0.18)
        } else if completedCount > 0 {
            fill = .orange.opacity(0.18)
        } else {
            fill = .blue.opacity(0.12)
        }

        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(fill)
    }

    private func monthLegend(title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint.opacity(0.8))
                .frame(width: 10, height: 10)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#endif
