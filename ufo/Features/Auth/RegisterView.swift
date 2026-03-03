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
                    TextField("Email", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                    SecureField("Hasło", text: $password)
                    SecureField("Powtórz hasło", text: $confirmPassword)
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
                        Text("Załóż konto")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(passwordValidationError != nil || !isEmailValid)
                }
            }
            .navigationTitle("Rejestracja")
            .alert("Błąd", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error ?? "Nie udało się utworzyć konta.")
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
            error = "Email jest niepoprawny."
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
