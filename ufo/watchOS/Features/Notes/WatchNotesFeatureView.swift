#if os(watchOS)
import SwiftUI

struct WatchNotesFeatureView: View {
    @Environment(WatchAppModel.self) private var model

    @State private var notes: [WatchNoteSummary] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isPresentingCreateSheet = false

    var body: some View {
        List {
            if isLoading {
                ProgressView("notes.view.loading")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if notes.isEmpty {
                Text("watch.notes.empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notes) { note in
                    NavigationLink {
                        WatchNoteDetailScreen(note: note) {
                            Task {
                                await loadNotes()
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(note.title)
                                    .font(.headline)
                                if note.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.footnote)
                                        .foregroundStyle(.yellow)
                                }
                            }

                            if !note.content.isEmpty {
                                Text(note.content)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            if let updatedAt = note.updatedAt {
                                Text(updatedAt, style: .relative)
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("notes.view.title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingCreateSheet) {
            WatchNoteEditorScreen(
                titleKey: "notes.editor.title.new",
                actionTitleKey: "watch.common.add"
            ) { title, content in
                _ = try await model.createNote(title: title, content: content)
                await loadNotes()
            }
        }
        .task(id: model.selectedSpaceID) {
            await loadNotes()
        }
        .refreshable {
            await loadNotes()
        }
    }

    private func loadNotes() async {
        isLoading = true
        defer { isLoading = false }

        do {
            notes = try await model.fetchNotes()
            errorMessage = nil
        } catch {
            notes = []
            errorMessage = String(localized: "watch.notes.error.load")
        }
    }
}

private struct WatchNoteDetailScreen: View {
    @Environment(WatchAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var note: WatchNoteSummary
    @State private var errorMessage: String?
    @State private var isPresentingEditSheet = false
    @State private var isDeleting = false

    let onDidChange: () -> Void

    init(note: WatchNoteSummary, onDidChange: @escaping () -> Void) {
        _note = State(initialValue: note)
        self.onDidChange = onDidChange
    }

    var body: some View {
        List {
            if !note.content.isEmpty {
                Section("notes.editor.field.content") {
                    Text(note.content)
                        .font(.body)
                }
            }

            Section("watch.common.info") {
                if note.isPinned {
                    Label("watch.notes.pinned", systemImage: "pin.fill")
                }

                if let updatedAt = note.updatedAt {
                    LabeledContent("watch.notes.updatedAt") {
                        Text(updatedAt, style: .relative)
                    }
                }
            }

            Section("watch.common.actions") {
                Button("common.edit") {
                    isPresentingEditSheet = true
                }

                Button("common.delete", role: .destructive) {
                    Task {
                        await deleteNote()
                    }
                }
                .disabled(isDeleting)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(note.title)
        .sheet(isPresented: $isPresentingEditSheet) {
            WatchNoteEditorScreen(
                titleKey: "notes.editor.title.edit",
                actionTitleKey: "common.save",
                initialTitle: note.title,
                initialContent: note.content
            ) { title, content in
                note = try await model.updateNote(note, title: title, content: content)
                onDidChange()
            }
        }
    }

    private func deleteNote() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await model.deleteNote(note)
            onDidChange()
            dismiss()
        } catch {
            errorMessage = String(localized: "watch.notes.error.delete")
        }
    }
}

private struct WatchNoteEditorScreen: View {
    @Environment(\.dismiss) private var dismiss

    let titleKey: String
    let actionTitleKey: String
    let initialTitle: String
    let initialContent: String
    let onSave: @Sendable (String, String) async throws -> Void

    @State private var noteTitle: String
    @State private var noteContent: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(
        titleKey: String,
        actionTitleKey: String,
        initialTitle: String = "",
        initialContent: String = "",
        onSave: @escaping @Sendable (String, String) async throws -> Void
    ) {
        self.titleKey = titleKey
        self.actionTitleKey = actionTitleKey
        self.initialTitle = initialTitle
        self.initialContent = initialContent
        self.onSave = onSave
        _noteTitle = State(initialValue: initialTitle)
        _noteContent = State(initialValue: initialContent)
    }

    var body: some View {
        List {
            Section("notes.editor.field.title") {
                TextField("notes.editor.field.title", text: $noteTitle)
            }

            Section("notes.editor.field.content") {
                TextField("watch.notes.editor.contentPlaceholder", text: $noteContent, axis: .vertical)
                    .lineLimit(4...8)
            }

            Section {
                Button(actionTitleKey) {
                    Task {
                        await save()
                    }
                }
                .disabled(isSaving || trimmedTitle.isEmpty)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(titleKey)
    }

    private var trimmedTitle: String {
        noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await onSave(trimmedTitle, noteContent.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Watch Note Detail") {
    let model = WatchAppModel()
    let note = WatchNoteSummary(
        id: UUID(),
        title: "Shopping reminder",
        content: "Buy fruit, milk and batteries on the way home.",
        isPinned: true,
        updatedAt: .now.addingTimeInterval(-3600),
        version: 1
    )

    return NavigationStack {
        WatchNoteDetailScreen(note: note, onDidChange: {})
            .environment(model)
    }
}

#Preview("Watch Note Editor") {
    NavigationStack {
        WatchNoteEditorScreen(
            titleKey: "notes.editor.title.new",
            actionTitleKey: "watch.common.add",
            initialTitle: "Packing list",
            initialContent: "Passport\nCharger\nSnacks"
        ) { _, _ in }
    }
}

#endif
