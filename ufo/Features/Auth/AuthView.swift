//
//  Untitled.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import SwiftUI

struct AuthView: View {
    @State private var isShowingLogin: Bool = true
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Group {
                if isShowingLogin {
                    LoginView()
                } else {
                    RegisterView()
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowingLogin)
            
            Spacer()
            
            Button {
                isShowingLogin.toggle()
            } label: {
                HStack {
                    Text(isShowingLogin ? "auth.toggle.prompt.register" : "auth.toggle.prompt.login")
                    Text(isShowingLogin ? "auth.toggle.action.register" : "auth.toggle.action.login")
                        .bold()
                }
                .font(.footnote)
            }
            .padding(.bottom, 20)
        }
        .padding()
    }
}

#Preview {
    let mockRepo = AuthMock.makeRepository(isLoggedIn: true)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    let authStore = AuthStore(authRepository: mockRepo, spaceRepository: spaceRepo)
     AuthView()
        .environment(mockRepo)
        .environment(authStore)
}
