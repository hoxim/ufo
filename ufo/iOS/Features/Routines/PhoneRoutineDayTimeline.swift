#if os(iOS)

import SwiftUI

struct PhoneRoutineDayTimeline: View {
    let date: Date
    let routines: [Routine]
    let logs: [RoutineLog]
    let onAdd: () -> Void
    let onLogRoutine: (Routine) -> Void

    private let hourRowHeight: CGFloat = 76

    private var calendar: Calendar { .current }

    private var timelineRange: ClosedRange<Int> {
        guard let first = routines.first, let last = routines.last else { return 6...22 }
        let startHour = max(0, (first.startMinuteOfDay / 60) - 1)
        let endHour = min(23, Int(ceil(Double(last.endMinuteOfDay) / 60.0)) + 1)
        return startHour...max(endHour, startHour + 1)
    }

    private var completedRoutineIds: Set<UUID> {
        Set(logs.map(\.routineId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoutineProgressSummary(
                scheduledCount: routines.count,
                completedCount: completedRoutineIds.count,
                logCount: logs.count
            )

            if routines.isEmpty {
                ContentUnavailableView(
                    "Brak rutyn",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Dodaj pierwszy stały rytm dnia, np. drzemkę, lek albo trening.")
                )
                .frame(maxWidth: .infinity, minHeight: 320)
                .overlay(alignment: .bottom) {
                    Button("Dodaj rutynę", action: onAdd)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    timelineBody(currentDate: context.date)
                }
            }
        }
    }

    private func timelineBody(currentDate: Date) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let labelWidth: CGFloat = 58
            let rowCount = timelineRange.count
            let timelineHeight = CGFloat(rowCount) * hourRowHeight
            let totalMinutes = max((timelineRange.upperBound - timelineRange.lowerBound + 1) * 60, 60)
            let pointsPerMinute = timelineHeight / CGFloat(totalMinutes)

            ZStack(alignment: .topLeading) {
                ForEach(Array(timelineRange.enumerated()), id: \.offset) { offset, hour in
                    let y = CGFloat(offset) * hourRowHeight

                    HStack(spacing: 12) {
                        Text(String(format: "%02d:00", hour))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(width: labelWidth, alignment: .leading)

                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 1)
                    }
                    .offset(y: y)
                }

                ForEach(routines) { routine in
                    let startOffsetMinutes = routine.startMinuteOfDay - (timelineRange.lowerBound * 60)
                    let y = CGFloat(startOffsetMinutes) * pointsPerMinute
                    let height = max(CGFloat(routine.durationMinutes) * pointsPerMinute, 108)
                    let routineLogs = logs
                        .filter { $0.routineId == routine.id }
                        .sorted { $0.loggedAt > $1.loggedAt }

                    RoutineTimelineCard(
                        routine: routine,
                        logs: routineLogs,
                        selectedDate: date,
                        onLog: { onLogRoutine(routine) }
                    )
                    .frame(width: width - labelWidth - 12, height: height, alignment: .topLeading)
                    .offset(x: labelWidth + 12, y: y + 10)
                }

                if calendar.isDate(date, inSameDayAs: currentDate) {
                    let currentMinutes = calendar.component(.hour, from: currentDate) * 60 + calendar.component(.minute, from: currentDate)
                    let lowerBoundMinutes = timelineRange.lowerBound * 60
                    let upperBoundMinutes = (timelineRange.upperBound + 1) * 60

                    if currentMinutes >= lowerBoundMinutes && currentMinutes <= upperBoundMinutes {
                        let y = CGFloat(currentMinutes - lowerBoundMinutes) * pointsPerMinute

                        HStack(spacing: 10) {
                            Text(currentDate.formatted(.dateTime.hour().minute()))
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red, in: Capsule())

                            Rectangle()
                                .fill(Color.red)
                                .frame(height: 2)
                        }
                        .offset(y: y)
                    }
                }
            }
            .frame(height: timelineHeight + 40)
        }
        .frame(minHeight: CGFloat(timelineRange.count) * hourRowHeight + 40)
    }
}

private struct RoutineProgressSummary: View {
    let scheduledCount: Int
    let completedCount: Int
    let logCount: Int

    var body: some View {
        HStack(spacing: 12) {
            summaryPill(title: "Zaplanowane", value: "\(scheduledCount)", tint: .blue)
            summaryPill(title: "Ukończone", value: "\(completedCount)", tint: .green)
            summaryPill(title: "Wpisy", value: "\(logCount)", tint: .orange)
        }
    }

    private func summaryPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct RoutineTimelineCard: View {
    let routine: Routine
    let logs: [RoutineLog]
    let selectedDate: Date
    let onLog: () -> Void

    private var lastLog: RoutineLog? { logs.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Label(routine.categoryValue.label, systemImage: routine.categoryValue.iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(routineTimeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(routine.title)
                .font(.headline)
                .foregroundStyle(.primary)

            if let personName = routine.personName, !personName.isEmpty {
                Text(personName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let notes = routine.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    if let lastLog {
                        Text("Ostatni wpis: \(lastLog.loggedAt.formatted(.dateTime.hour().minute()))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Text(statusText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if logs.count > 1 {
                        Text("Łącznie wpisów: \(logs.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: onLog) {
                    Label(logButtonTitle, systemImage: logs.isEmpty ? "checkmark.circle.fill" : "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(Color.secondarySystemBackgroundAdaptive, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var routineTimeLabel: String {
        let startHour = routine.startMinuteOfDay / 60
        let startMinute = routine.startMinuteOfDay % 60
        let endHour = routine.endMinuteOfDay / 60
        let endMinute = routine.endMinuteOfDay % 60
        return String(format: "%02d:%02d-%02d:%02d", startHour, startMinute, endHour, endMinute)
    }

    private var statusText: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Do zrobienia dzisiaj"
        }
        return "Brak wpisu dla tego dnia"
    }

    private var logButtonTitle: String {
        logs.isEmpty ? "Zaloguj" : "Dodaj wpis"
    }
}

#endif
