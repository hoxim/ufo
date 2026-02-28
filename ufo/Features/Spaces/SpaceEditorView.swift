//
//  SpaceEditorView.swift
//  ufo
//
//  Created by Marcin Ryzko on 10/02/2026.
//


import SwiftUI

struct SpaceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo
    
    var spaceToEdit: Space?
    
    @State private var name: String = ""
    @State private var selectedType: SpaceType = .family
    @State private var isProcessing: Bool = false
    
    init(space: Space? = nil) {
        self.spaceToEdit = space
        _name = State(initialValue: space?.name ?? "")
        _selectedType = State(initialValue: .family)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Space Details") {
                    TextField("Space Name (e.g. Alpha Crew)", text: $name)
                    
                    Picker("Space Type", selection: $selectedType) {
                        ForEach(SpaceType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section {
                    Button(action: saveSpace) {
                        if isProcessing {
                            ProgressView()
                        } else {
                            Text(spaceToEdit == nil ? "Create Crew" : "Save Changes")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(name.isEmpty || isProcessing)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle(spaceToEdit == nil ? "New Space" : "Edit Space")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
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
