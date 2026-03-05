//
//  RegisterView.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import SwiftUI

struct RegisterView: View {
    @Environment(AuthStore.self) private var authStore
    @State var email:String = ""
    @State var confirmPassword:String = ""
    @State var password:String = ""
    @State var error:String? = nil
    @State var showError: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("auth.register.email", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                    SecureField("auth.register.password", text: $password)
                    SecureField("auth.register.confirm", text: $confirmPassword)
                }

                if let validationError = passwordValidationError, !password.isEmpty {
                    Section {
                        Text(validationError.localizedDescription)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await signUp() }
                    } label: {
                        Text("auth.register.button")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(passwordValidationError != nil || !isEmailValid)
                }

                Section {
                    Button {
                        Task { await signInWithOAuth(.google) }
                    } label: {
                        Text("auth.social.google")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(authStore.state == .checkingSession)

                    Button {
                        Task { await signInWithOAuth(.apple) }
                    } label: {
                        Text("auth.social.apple")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(authStore.state == .checkingSession)
                } header: {
                    Text("auth.social.section")
                }
            }
            .navigationTitle("auth.register.title")
            .alert("common.error", isPresented: $showError) {
                Button("common.ok", role: .cancel) { }
            } message: {
                Text(error ?? String(localized: "auth.register.error.create"))
            }
        }
    }
    
    var isEmailValid: Bool {
        !email.isEmpty && email
            .contains("@") && email
            .contains(".")
    }
    
    var idPasswordValid:Bool {
        password == confirmPassword && !password.isEmpty
    }
    
     var passwordValidationError: PasswordError? {
        switch PasswordValidator.validate(password: password, confirm: confirmPassword) {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
    
    /// Handles sign up.
    func signUp() async {
        guard isEmailValid else {
            error = String(localized: "auth.register.error.invalidEmail")
            showError = true
            return
        }
        do{
            try await authStore.signUp(email: email, password: password)
        }
        catch (let error){
            self.error = error.localizedDescription
            showError = true
        }
    }

    /// Handles social sign in.
    func signInWithOAuth(_ provider: SocialAuthProvider) async {
        await authStore.signInWithOAuth(provider: provider)
        if let storeError = authStore.errorMessage {
            error = storeError
            showError = true
        }
    }
}

#Preview("Register Light Mode") {
    let mockRepo = AuthMock.makeRepository()
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    let authStore = AuthStore(authRepository: mockRepo, spaceRepository: spaceRepo)
    return RegisterView()
        .environment(mockRepo)
        .environment(authStore)
}

#Preview("Register Dark Mode") {
    let mockRepo = AuthMock.makeRepository(isLoggedIn: true)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    let authStore = AuthStore(authRepository: mockRepo, spaceRepository: spaceRepo)
    return RegisterView()
        .environment(mockRepo)
        .environment(authStore)
        .preferredColorScheme(.dark)
}
