#if os(iOS)

//
//  PadSpaceSelectorScreen.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import SwiftUI
import SwiftData

struct PadSpaceSelectorScreen: View {
    @Environment(SpaceRepository.self) private var spaceRepo
    
    let userSpaces: [Space]
    @State private var showCreator = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                    ForEach(userSpaces) { space in
                        Button {
                            withAnimation {
                                spaceRepo.selectedSpace = space
                            }
                        } label: {
                            Card {
                                Image(systemName: "group.icon")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white)
                                    .frame(width: 80, height: 80)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                
                                Text(space.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)

                        }
                    }
                    
                    //  "Add new"
                    Button {
                        showCreator = true
                    } label: {
                        Card {
                            Image(systemName: "plus")
                                .font(.system(size: 40))
                                .frame(width: 80, height: 80)
                                .frame(maxWidth: .infinity)
                                
                            Text("spaces.selector.create")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("spaces.selector.title")
            .sheet(isPresented: $showCreator) {
                PadSpaceEditorView()
            }
        }
    }
}

#Preview("Light mode") {
    let previewSchema = Schema([
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        SpaceInvitation.self,
        Mission.self,
        Incident.self,
        LinkedThing.self,
        Assignment.self
    ])
    let container = try! ModelContainer(for: previewSchema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    let spaces = PadSpaceMock.makeSampleData(context: context)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)

    PadSpaceSelectorScreen(userSpaces: spaces)
        .environment(spaceRepo)
        .modelContainer(container)

}

#endif
