//
//  SpaceSelectorView.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import SwiftUI
import SwiftData
import Supabase

struct SpaceSelectorView: View {
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo
    
    let userSpaces: [Space]
    
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
                        // open creator
                    } label: {
                        Card {
                            Image(systemName: "plus")
                                .font(.system(size: 40))
                                .frame(width: 80, height: 80)
                                .frame(maxWidth: .infinity)
                                
                            Text("Create New")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Select Base")
        }
    }
}

#Preview("Light mode") {
    let container = try! ModelContainer(for: Space.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    let spaces = SpaceMock.makeSampleData(context: context)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    let authRepo = AuthRepository(client: SupabaseConfig.client)

    SpaceSelectorView(userSpaces: spaces)
        .environment(spaceRepo)
        .environment(authRepo)
        .modelContainer(container)

}
