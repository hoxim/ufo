//
//  NoGroupView.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import SwiftUI

struct NoGroupView: View {
    
    var groupRepository: GroupRepository
    
    init(groupRepository: GroupRepository) {
        self.groupRepository = groupRepository
    }
    
    var body: some View {
        VStack(spacing: 20) {
            GroupBox {
                Text("There is no group, create one!")
                    .padding()
            }
            
            Button("Create Group") {
                Task {
                    try? await groupRepository.createGroup(name: "New Family Base", type: "Family")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
