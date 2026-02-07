//
//  Untitled.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import Foundation
import Observation

@Observable
@MainActor
class LoginViewModel {
    var email: String = ""
    var password: String = ""
    var error: String? = nil
    var isProcessing: Bool = false
    
    
    private let authRepository: AuthRepository
    
    init(authRepository:AuthRepository){
        self.authRepository = authRepository
    }
    
    func signIn() async {
        isProcessing = true
        error = nil
        
        do {
            _ = try await authRepository.signIn(email: email, password: password)
            self.error = nil
        } catch {
            self.error = "Invalid email or password"
        }
        isProcessing = false
    }
    
    
}
