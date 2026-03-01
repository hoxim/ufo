//
//  LoginView.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var authStore
    @State var email: String = ""
    @State var password: String = ""
    @State var error: String? = nil
    @State var showError:Bool = false
    
    private var isFormValid: Bool {
        isValidEmail(email) && !password.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                    SecureField("Hasło", text: $password)
                }

                Section {
                    Button {
                        Task { await signIn() }
                    } label: {
                        if authStore.state == .checkingSession {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Zaloguj się")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isFormValid || authStore.state == .checkingSession)
                }
            }
            .navigationTitle("Logowanie")
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
        await authStore.signIn(email: email, password: password)
        if let storeError = authStore.errorMessage {
            self.error = storeError
            showError = true
        }
    }
}

#Preview("Logged Out State") {
    let mockRepo = AuthMock.makeRepository(isLoggedIn: false)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    let authStore = AuthStore(authRepository: mockRepo, spaceRepository: spaceRepo)
    return LoginView()
        .environment(mockRepo)
        .environment(authStore)
}

#Preview("Login Dark Mode") {
    let mockRepo = AuthMock.makeRepository(isLoggedIn: true)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    let authStore = AuthStore(authRepository: mockRepo, spaceRepository: spaceRepo)
    return LoginView()
        .environment(mockRepo)
        .environment(authStore)
        .preferredColorScheme(.dark)
}
