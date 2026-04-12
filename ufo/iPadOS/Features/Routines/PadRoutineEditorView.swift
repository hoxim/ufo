#if os(iOS)

import SwiftUI
import SwiftData

struct PadRoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let spaceId: UUID
    let actorId: UUID?
    let onSave: () -> Void

    @State private var title = ""
    @State private var category: RoutineCategory = .other
    @State private var personName = ""
    @State private var notes = ""
    @State private var startTime = PadRoutineEditorView.defaultTime
    @State private var durationMinutes = 30
    @State private var selectedWeekdays: Set<Int> = Set(1...7)
    @FocusState private var isTitleFocused: Bool

    private static let defaultTime: Date = {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    }()

    var body: some View {
        AdaptiveFormContent {
            Form {
                Section("routines.editor.section.routine") {
                    TextField("routines.editor.field.title", text: $title)
                        .prominentFormTextInput()
                        .focused($isTitleFocused)

                    Picker("routines.editor.field.category", selection: $category) {
                        ForEach(RoutineCategory.allCases) { category in
                            Label(category.label, systemImage: category.iconName).tag(category)
                        }
                    }

                    TextField("routines.editor.field.person", text: $personName)
                        .prominentFormTextInput()
                    TextField("routines.editor.field.note", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                        .prominentFormTextInput()
                }

                Section("routines.editor.section.time") {
                    DatePicker("routines.editor.field.startTime", selection: $startTime, displayedComponents: .hourAndMinute)
                    Stepper(String(format: String(localized: "routines.editor.field.durationValue"), durationMinutes), value: $durationMinutes, in: 15...240, step: 15)
                }

                Section("routines.editor.section.weekdays") {
                    weekdayPicker
                }
            }
            .navigationTitle("routines.editor.title.new")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }
                ModalConfirmToolbarItem(
                    isDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedWeekdays.isEmpty,
                    isProcessing: false,
                    action: save
                )
            }
            .onAppear {
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    isTitleFocused = true
                }
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
                                .fill(selectedWeekdays.contains(item.weekday) ? Color.accentColor.opacity(0.18) : Color.secondarySystemBackgroundAdaptive)
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
            Log.dbError("PadRoutineEditorView.save", error)
        }
    }

    private func calendarSymbols() -> [(weekday: Int, label: String)] {
        let symbols = Calendar.current.shortWeekdaySymbols
        return symbols.enumerated().map { (offset, label) in
            (weekday: offset + 1, label: label)
        }
    }
}

#Preview("Pad Routine Editor") {
    let container = try! ModelContainer(
        for: Schema([Routine.self]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return NavigationStack {
        PadRoutineEditorView(
            spaceId: UUID(),
            actorId: UUID(),
            onSave: {}
        )
    }
    .modelContainer(container)
}

#endif
