import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var selectedDate = Date()
    @State private var selectedRange: RoutineRange = .day
    @State private var routines: [Routine] = []
    @State private var routineLogs: [RoutineLog] = []
    @State private var showingCreator = false

    private var calendar: Calendar { .current }

    var body: some View {
        Group {
            if let selectedSpace = spaceRepo.selectedSpace {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(for: selectedDate)

                        Picker("Zakres", selection: $selectedRange) {
                            ForEach(RoutineRange.allCases) { range in
                                Text(range.title).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch selectedRange {
                        case .day:
                            RoutineDayTimeline(
                                date: selectedDate,
                                routines: routinesForSelectedDay,
                                logs: logsForSelectedDay,
                                onAdd: { showingCreator = true },
                                onLogRoutine: { routine in
                                    logRoutine(routine, on: selectedDate)
                                }
                            )
                        case .week:
                            RoutineWeekView(
                                startDate: startOfWeek(for: selectedDate),
                                routines: routines,
                                logs: routineLogs
                            )
                        case .month:
                            RoutineMonthView(
                                monthDate: selectedDate,
                                routines: routines,
                                logs: routineLogs
                            )
                        }
                    }
                    .padding()
                }
                .navigationTitle("Routines")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            moveDate(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }

                        Button {
                            moveDate(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }

                        Button {
                            showingCreator = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingCreator) {
                    NavigationStack {
                        RoutineEditorView(spaceId: selectedSpace.id, actorId: authRepo.currentUser?.id) {
                            loadData()
                        }
                    }
                }
                .task {
                    loadData()
                }
                .onChange(of: spaceRepo.selectedSpace?.id) { _, _ in
                    loadData()
                }
            } else {
                ContentUnavailableView(
                    "Wybierz grupę",
                    systemImage: "person.3.sequence",
                    description: Text("Najpierw wybierz grupę, żeby zobaczyć plan routines.")
                )
            }
        }
    }

    private func header(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(date.formatted(.dateTime.day().month(.wide).year()))
                .font(.largeTitle.bold())
            Text(date.formatted(.dateTime.weekday(.wide)))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var routinesForSelectedDay: [Routine] {
        routines
            .filter { $0.isActive(on: selectedDate, calendar: calendar) }
            .sorted { $0.startMinuteOfDay < $1.startMinuteOfDay }
    }

    private var logsForSelectedDay: [RoutineLog] {
        routineLogs.filter { calendar.isDate($0.loggedAt, inSameDayAs: selectedDate) }
    }

    private func loadData() {
        guard let spaceId = spaceRepo.selectedSpace?.id else {
            routines = []
            routineLogs = []
            return
        }

        do {
            routines = try modelContext.fetch(
                FetchDescriptor<Routine>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.startMinuteOfDay, order: .forward)]
                )
            )

            routineLogs = try modelContext.fetch(
                FetchDescriptor<RoutineLog>(
                    predicate: #Predicate { $0.spaceId == spaceId },
                    sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
                )
            )
        } catch {
            routines = []
            routineLogs = []
            Log.dbError("RoutinesView.loadData", error)
        }
    }

    private func logRoutine(_ routine: Routine, on date: Date) {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return }

        let log = RoutineLog(
            routineId: routine.id,
            spaceId: spaceId,
            loggedAt: defaultLogDate(for: routine, on: date),
            createdBy: authRepo.currentUser?.id
        )

        modelContext.insert(log)

        do {
            try modelContext.save()
            notifyHomeWidgetsDataDidChange()
            loadData()
        } catch {
            Log.dbError("RoutinesView.logRoutine", error)
        }
    }

    private func defaultLogDate(for routine: Routine, on date: Date) -> Date {
        if calendar.isDateInToday(date) {
            return .now
        }

        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .minute, value: routine.startMinuteOfDay, to: startOfDay) ?? startOfDay
    }

    private func moveDate(by value: Int) {
        switch selectedRange {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: value, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .day, value: value * 7, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: value, to: selectedDate) ?? selectedDate
        }
    }

    private func startOfWeek(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
}

private enum RoutineRange: CaseIterable, Identifiable {
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

private struct RoutineDayTimeline: View {
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
                    "Brak routines",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Dodaj pierwszy stały rytm dnia, np. drzemkę, lek albo trening.")
                )
                .frame(maxWidth: .infinity, minHeight: 320)
                .overlay(alignment: .bottom) {
                    Button("Dodaj routine", action: onAdd)
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

private struct RoutineWeekView: View {
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
                        Text("Nic zaplanowanego")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 10) {
                            weekPill(title: "Plan", value: "\(dayRoutines.count)", tint: .blue)
                            weekPill(title: "Done", value: "\(completedRoutineIds.count)", tint: .green)
                            weekPill(title: "Wpisy", value: "\(dayLogs.count)", tint: .orange)
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
                            Text("+ \(dayRoutines.count - 3) więcej")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

private struct RoutineMonthView: View {
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
                monthLegend(title: "Zaplanowane", tint: .blue)
                monthLegend(title: "Wykonane", tint: .green)
                monthLegend(title: "Słabiej", tint: .orange)
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
            fill = Color(.secondarySystemBackground).opacity(0.45)
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

private struct RoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let spaceId: UUID
    let actorId: UUID?
    let onSave: () -> Void

    @State private var title = ""
    @State private var category: RoutineCategory = .other
    @State private var personName = ""
    @State private var notes = ""
    @State private var startTime = RoutineEditorView.defaultTime
    @State private var durationMinutes = 30
    @State private var selectedWeekdays: Set<Int> = Set(1...7)

    private static let defaultTime: Date = {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    }()

    var body: some View {
        Form {
            Section("Routine") {
                TextField("Tytuł", text: $title)

                Picker("Kategoria", selection: $category) {
                    ForEach(RoutineCategory.allCases) { category in
                        Label(category.label, systemImage: category.iconName).tag(category)
                    }
                }

                TextField("Dla kogo", text: $personName)
                TextField("Notatka", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section("Czas") {
                DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                Stepper("Czas trwania: \(durationMinutes) min", value: $durationMinutes, in: 15...240, step: 15)
            }

            Section("Dni") {
                weekdayPicker
            }
        }
        .navigationTitle("Nowa routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Anuluj") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Zapisz") {
                    save()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedWeekdays.isEmpty)
            }
        }
    }

    private var weekdayPicker: some View {
        let symbols = calendarSymbols()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(symbols, id: \.weekday) { item in
                Button {
                    if selectedWeekdays.contains(item.weekday) {
                        selectedWeekdays.remove(item.weekday)
                    } else {
                        selectedWeekdays.insert(item.weekday)
                    }
                } label: {
                    Text(item.label)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedWeekdays.contains(item.weekday) ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPersonName = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: startTime)
        let minute = calendar.component(.minute, from: startTime)

        let routine = Routine(
            spaceId: spaceId,
            title: cleanTitle,
            category: category.rawValue,
            personName: cleanPersonName.isEmpty ? nil : cleanPersonName,
            notes: cleanNotes.isEmpty ? nil : cleanNotes,
            startMinuteOfDay: (hour * 60) + minute,
            durationMinutes: durationMinutes,
            activeWeekdays: selectedWeekdays.sorted(),
            createdBy: actorId,
            updatedBy: actorId
        )

        modelContext.insert(routine)

        do {
            try modelContext.save()
            notifyHomeWidgetsDataDidChange()
            onSave()
            dismiss()
        } catch {
            Log.dbError("RoutineEditorView.save", error)
        }
    }

    private func calendarSymbols() -> [(weekday: Int, label: String)] {
        let symbols = Calendar.current.shortWeekdaySymbols
        return symbols.enumerated().map { (offset, label) in
            (weekday: offset + 1, label: label)
        }
    }
}

#Preview("Routines") {
    let schema = Schema([
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        Routine.self,
        RoutineLog.self
    ])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    let membership = SpaceMembership(user: user, space: space, role: "admin")
    let todayWeekday = Calendar.current.component(.weekday, from: .now)

    context.insert(user)
    context.insert(space)
    context.insert(membership)

    let breakfast = Routine(spaceId: space.id, title: "Śniadanie", category: RoutineCategory.food.rawValue, personName: "Leo", startMinuteOfDay: 450, durationMinutes: 30, activeWeekdays: [todayWeekday], createdBy: user.id)
    let nap = Routine(spaceId: space.id, title: "Drzemka", category: RoutineCategory.sleep.rawValue, personName: "Leo", startMinuteOfDay: 780, durationMinutes: 75, activeWeekdays: [todayWeekday], createdBy: user.id)
    let training = Routine(spaceId: space.id, title: "Trening", category: RoutineCategory.training.rawValue, personName: "Mama", startMinuteOfDay: 1080, durationMinutes: 60, activeWeekdays: [todayWeekday], createdBy: user.id)

    context.insert(breakfast)
    context.insert(nap)
    context.insert(training)
    context.insert(RoutineLog(routineId: breakfast.id, spaceId: space.id, loggedAt: .now.addingTimeInterval(-60 * 60), createdBy: user.id))
    context.insert(RoutineLog(routineId: nap.id, spaceId: space.id, loggedAt: .now.addingTimeInterval(-20 * 60), createdBy: user.id))
    try! context.save()

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return NavigationStack {
        RoutinesView()
    }
    .environment(authRepo)
    .environment(spaceRepo)
    .modelContainer(container)
}
