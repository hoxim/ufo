//
//  LoginView.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthRepository.self) private var authRepository: AuthRepository
    @State private var mv: LoginViewModel
    
    init(authRepository: AuthRepository) {
        _mv = State(
            initialValue: LoginViewModel(authRepository: authRepository)
        )
    }
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Login")
                .font(.title)
                .bold()
            
            TextField("Email", text: $mv.email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .autocorrectionDisabled(true)
#if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
#endif
            
            SecureField("Password", text: $mv.password)
                .textFieldStyle(.roundedBorder)
            
            Button("Login") {
                Task {
                    await mv.signIn()
                }
            }
            .buttonStyle(.borderedProminent)
            // Example of using our validation logic
            
        }
        .padding()
    }
}

#Preview("Logged Out State") {
    let mockRepo = AuthMock.makeRepository(isLoggedIn: false)
    return LoginView(authRepository: mockRepo)
        .environment(mockRepo)
}

#Preview("Logged In State") {
    let mockRepo = AuthMock.makeRepository(isLoggedIn: true)
    return LoginView(authRepository: mockRepo)
        .environment(mockRepo)
}
