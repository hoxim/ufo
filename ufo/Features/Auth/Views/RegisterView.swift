//
//  RegisterView.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import SwiftUI

struct RegisterView: View {
    @State private var mv: RegisterViewModel
    
    init(authRepository: AuthRepository) {
        _mv = State(initialValue: RegisterViewModel(authRepository: authRepository))
    }
    
    
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Join the Crew")
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
            
            SecureField("Confirm password", text: $mv.confirmPassword)
                .textFieldStyle(.roundedBorder)
            
            if let error = mv.passwordValidationError, !mv.password.isEmpty {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button("Register for Mission") {
                Task {
                    await mv.signUp()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                mv.passwordValidationError != nil || !mv.isEmailValid
            )
        }
        .padding()
    }
}

#Preview("Logged Out State") {
    let mockRepo = AuthMock.makeRepository(isLoggedIn: false)
    return RegisterView(authRepository: mockRepo)
        .environment(mockRepo)
}
