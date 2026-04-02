#if os(macOS)

//
//  Untitled.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import SwiftUI

struct MacAuthScreen: View {
    @State private var isShowingLogin: Bool = true
    
    var body: some View {
        ZStack {
            authBackgroundColor.ignoresSafeArea(edges: .all)
            
            VStack(spacing: 20) {
                Group {
                    if isShowingLogin {
                        MacLoginScreen()
                    } else {
                        MacRegisterScreen()
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
            }
            .padding()
        }
    }
}

private extension MacAuthScreen {
    var authBackgroundColor: Color {
        return Color(nsColor: .windowBackgroundColor)
    }
}

#Preview {
    let mockRepo = AuthMock.makeRepository(isLoggedIn: true)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    let authStore = AuthStore(authRepository: mockRepo, spaceRepository: spaceRepo)
     MacAuthScreen()
        .environment(mockRepo)
        .environment(authStore)
}

#endif
