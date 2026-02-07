//
//  RegisterViewModel.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//


import Foundation
import Observation

@Observable
class RegisterViewModel {
    
    var email:String = ""
    var confirmPassword:String = ""
    var password:String = ""
    private var error:String? = nil
    let passwordMinimalCount:Int = 6
    
    private let authRepository:AuthRepository
    
    init(authRepository:AuthRepository){
        self.authRepository = authRepository
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
