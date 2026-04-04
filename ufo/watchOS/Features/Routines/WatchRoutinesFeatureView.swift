#if os(watchOS)
import SwiftUI

struct WatchRoutinesFeatureView: View {
    @Environment(WatchAppModel.self) private var model

    @State private var routines: [WatchRoutineSummary] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        List {
            if isLoading {
                ProgressView("watch.routines.loading")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if routines.isEmpty {
                Text("watch.routines.empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(routines) { routine in
                    NavigationLink {
                        WatchRoutineDetailScreen(routine: routine)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(routine.title)
                            Text(routineTimeLabel(for: routine))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("watch.routines.title")
        .task(id: model.selectedSpaceID) {
            await loadRoutines()
        }
        .refreshable {
            await loadRoutines()
        }
    }

    private func loadRoutines() async {
        isLoading = true
        defer { isLoading = false }

        do {
            routines = try await model.fetchRoutines()
            errorMessage = nil
        } catch {
            routines = []
            errorMessage = String(localized: "watch.routines.error.load")
        }
    }
}

private struct WatchRoutineDetailScreen: View {
    @Environment(WatchAppModel.self) private var model

    let routine: WatchRoutineSummary

    @State private var logNote = ""
    @State private var isSaving = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("watch.routines.schedule") {
                LabeledContent("watch.routines.time") {
                    Text(routineTimeLabel(for: routine))
                }

                LabeledContent("watch.routines.days") {
                    Text(routineWeekdayLabel(for: routine))
                }

                if let personName = routine.personName, !personName.isEmpty {
                    LabeledContent("watch.routines.person") {
                        Text(personName)
                    }
                }
            }

            if let notes = routine.notes, !notes.isEmpty {
                Section("watch.routines.notes") {
                    Text(notes)
                }
            }

            Section("watch.routines.quickLog") {
                TextField("watch.routines.notePlaceholder", text: $logNote, axis: .vertical)
                    .lineLimit(2...4)

                Button("watch.routines.logNow") {
                    Task {
                        await logRoutine()
                    }
                }
                .disabled(isSaving)
            }

            if let resultMessage {
                Section {
                    Text(resultMessage)
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(routine.title)
    }

    private func logRoutine() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await model.logRoutine(routine, note: logNote)
            resultMessage = String(localized: "watch.routines.success.logged")
            errorMessage = nil
            logNote = ""
        } catch {
            resultMessage = nil
            errorMessage = String(localized: "watch.routines.error.log")
        }
    }
}

private func routineTimeLabel(for routine: WatchRoutineSummary) -> String {
    "\(watchClockTime(for: routine.startMinuteOfDay)) - \(watchClockTime(for: routine.startMinuteOfDay + routine.durationMinutes))"
}

private func routineWeekdayLabel(for routine: WatchRoutineSummary) -> String {
    let formatter = DateFormatter()
    formatter.locale = .current
    let symbols = formatter.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let labels = routine.activeWeekdays.map { symbols[max(0, min(symbols.count - 1, $0 - 1))] }
    return labels.joined(separator: ", ")
}

private func watchClockTime(for minuteOfDay: Int) -> String {
    let normalizedMinute = max(0, minuteOfDay)
    let hours = (normalizedMinute / 60) % 24
    let minutes = normalizedMinute % 60
    return String(format: "%02d:%02d", hours, minutes)
}

#endif
