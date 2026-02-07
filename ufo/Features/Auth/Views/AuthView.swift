//
//  Untitled.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import SwiftUI

struct AuthView: View {
    @Environment(AuthRepository.self) var authRepository: AuthRepository
    @State private var isShowingLogin: Bool = true
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Używamy SwiftUI. aby uniknąć konfliktu z Twoim modelem Group
            SwiftUI.Group {
                if isShowingLogin {
                    LoginView(authRepository: authRepository)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else {
                    RegisterView(authRepository: authRepository)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowingLogin)
            
            Spacer()
            
            Button {
                isShowingLogin.toggle()
            } label: {
                HStack {
                    Text(isShowingLogin ? "Don't have an account?" : "Already have an account?")
                    Text(isShowingLogin ? "Create one" : "Sign in")
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
     AuthView()
        .environment(mockRepo)
}
