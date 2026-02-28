//
//  RegisterView.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import SwiftUI

struct RegisterView: View {
    @Environment(AuthRepository.self) private var authRepository
    @State var email:String = ""
    @State var confirmPassword:String = ""
    @State var password:String = ""
    @State var error:String? = nil
    let passwordMinimalCount:Int = 6
    
    var body: some View {
        Card {
            Text("auth.register.title").font(.title).bold()
                .padding([.top, .bottom], 24)
            VStack (spacing: 12) {
                UfoTextField(title: "auth.register.email", text: $email)
                UfoSecureField(title: "auth.register.password", text: $password)
                UfoSecureField(title: "auth.register.confirm", text: $confirmPassword)
            }
            
            if let error = passwordValidationError, !password.isEmpty {
                Text(error.localizedDescription).foregroundColor(.red).font(.caption)
            }
            
            Button("auth.register.button") {
                Task { await signUp() }
            }
            .ufoPrimaryButton()
            .padding([.top, .bottom], 24)
            .disabled(passwordValidationError != nil || !isEmailValid)
        }.padding([.leading, .trailing], 24)
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
    
    func signUp() async {
        guard isEmailValid else {
            error = "Emails must match and be valid."
            return
        }
        do{
            try await authRepository.signUp(email: email, password: password)
        }
        catch (let error){
            print(error.localizedDescription)
        }
    }
}

#Preview("Register Light Mode") {
    let mockRepo = AuthMock.makeRepository()
    return RegisterView()
        .environment(mockRepo)
}

#Preview("Register Dark Mode") {
    let mockRepo = AuthMock.makeRepository(isLoggedIn: true)
    return RegisterView()
        .environment(mockRepo)
        .preferredColorScheme(.dark)
}
