//
//  SpaceEditorView.swift
//  ufo
//
//  Created by Marcin Ryzko on 10/02/2026.
//


import SwiftUI

struct MacSpaceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo
    @Environment(AppPreferences.self) private var appPreferences
    
    var spaceToEdit: Space?
    
    @State private var name: String = ""
    @State private var selectedType: SpaceType = .family
    @State private var isProcessing: Bool = false
    
    init(space: Space? = nil) {
        self.spaceToEdit = space
        _name = State(initialValue: space?.name ?? "")
        if let category = space?.category {
            _selectedType = State(initialValue: SpaceType(category: category))
        } else {
            _selectedType = State(initialValue: .personal)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("spaces.editor.section.details") {
                    TextField("spaces.editor.field.name", text: $name)
                    
                    Picker("spaces.editor.field.type", selection: $selectedType) {
                        Text("spaces.editor.type.private").tag(SpaceType.personal)
                        if appPreferences.allowsSharedSpaces {
                            Text("spaces.editor.type.shared").tag(SpaceType.shared)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!appPreferences.allowsSharedSpaces)

                    if !appPreferences.allowsSharedSpaces || selectedType == .personal || selectedType == .private {
                        Text("spaces.editor.note.private")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("spaces.editor.note.shared")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(spaceToEdit == nil ? "spaces.editor.title.new" : "spaces.editor.title.edit")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem { dismiss() }
                ModalConfirmToolbarItem(
                    isDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing,
                    isProcessing: isProcessing,
                    action: saveSpace
                )
            }
        }
    }
    
    /// Saves space.
    private func saveSpace() {
        isProcessing = true
        
        Task {
            do {
                if spaceToEdit != nil {
                    dismiss()
                } else {

                    try await spaceRepo.createSpace(name: name, type: selectedType)

                    if let userId = authRepo.currentUser?.id {
                        try await authRepo.fetchUserProfile(id: userId)
                    }

                    dismiss()
                }
            } catch {
                Log.error(error)
            }
            
            isProcessing = false
        }
    }
}

#Preview("Create Space") {
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    let authRepo = AuthRepository(client: SupabaseConfig.client)
    MacSpaceEditorView()
        .environment(spaceRepo)
        .environment(authRepo)
}
