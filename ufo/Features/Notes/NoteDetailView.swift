//
//  NoteDetailView.swift
//  ufo
//
//  Created by Marcin Ryzko on 17/03/2026.
//

import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    let note: Note
    let onEdit: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(note.title)
                        .font(.title2.bold())
                    
                    if !note.content.isEmpty {
                        Text(note.content)
                            .font(.body)
                    }
                    
                    if let url = note.attachedLinkURL, !url.isEmpty, let validURL = URL(string: url) {
                        Link(destination: validURL) {
                            Label(url, systemImage: "link")
                                .lineLimit(1)
                        }
                    }
                    
                    if note.relatedIncidentId != nil {
                        Label("notes.view.badge.incident", systemImage: "bolt.horizontal")
                            .font(.caption)
                    }
                    
                    if note.relatedLocationLatitude != nil && note.relatedLocationLongitude != nil {
                        Label(note.relatedLocationLabel ?? String(localized: "notes.view.badge.location"), systemImage: "location")
                            .font(.caption)
                    }

                    if let savedPlaceName = note.savedPlaceName, !savedPlaceName.isEmpty {
                        Label(savedPlaceName, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                    }
                    
                    Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("notes.view.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onEdit()
                    } label: {
                        Label("common.edit", systemImage: "pencil")
                    }
                }
            }
        }
    }
}

#Preview("Note Detail") {
    let preview = NotesPreviewFactory.make()

    return NoteDetailView(
        note: preview.note,
        onEdit: {}
    )
    .modelContainer(preview.container)
}
