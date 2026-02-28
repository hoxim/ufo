//
//  LoginView.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthRepository.self) private var authRepository
    @State var email: String = ""
    @State var password: String = ""
    @State var error: String? = nil
    @State var showError:Bool = false
    
    private var isFormValid: Bool {
        isValidEmail(email) && !password.isEmpty
    }
    
    var body: some View {
        ZStack{
            Color.backgroundSolid.ignoresSafeArea()
            Card {
                Text("auth.login.title").font(.title).bold().padding(.bottom, 44)
                
                UfoTextField(title: "auth.login.email", text: $email)
                
                UfoSecureField(title: "auth.login.password", text: $password)
                
                Button("auth.login.button") {
                    Task { await signIn() }
                }
                .ufoPrimaryButton()
                .disabled(isFormValid)
                .padding(.top, 44)
            }
            .padding([.leading, .trailing], 24)
            .alert("auth.login.error.title", isPresented: $showError) {
                Button("auth.login.ok", role: .cancel) { }
            } message: {
                Text(error ?? String(localized: "auth.login.error.unknown"))
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        email.contains("@") &&
        email.contains(".") &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    
    
    private func signIn() async {
        do {
            try await authRepository.signIn(email: email, password: password)
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
    }
}

#Preview("Logged Out State") {
    let mockRepo = AuthMock.makeRepository(isLoggedIn: false)
    return LoginView()
        .environment(mockRepo)
}

#Preview("Login Dark Mode") {
    let mockRepo = AuthMock.makeRepository(isLoggedIn: true)
    return LoginView()
        .environment(mockRepo)
        .preferredColorScheme(.dark)
}
