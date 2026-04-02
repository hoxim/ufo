#if os(iOS)

//
//  PadNoSpaceScreen.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import SwiftUI

struct PadNoSpaceScreen: View {
    var spaceRepository: SpaceRepository
    @State private var isShowingCreator = false
    
    init(spaceRepository: SpaceRepository) {
        self.spaceRepository = spaceRepository
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("spaces.noSpace.title")
                    .font(.title2)
                    .bold()
                
                Text("spaces.noSpace.body")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            
            Button {
                isShowingCreator = true
            } label: {
                Label("spaces.noSpace.create", systemImage: "plus")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $isShowingCreator) {
            PadSpaceEditorView()
        }
    }
}

#Preview {
    let repo = SpaceRepository(client: SupabaseConfig.client)
    PadNoSpaceScreen(spaceRepository: repo)
}

#endif
