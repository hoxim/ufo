//
//  PasswordValidator.swift
//  ufo
//
//  Created by Marcin Ryzko on 01/02/2026.
//

import Foundation

enum PasswordError: Error, LocalizedError {
    case empty
    case mismatch
    case tooShort(min: Int)
    case missingUppercase
    case missingNumber
    case missingSpecialCharacter
    
    // Friendly messages for the UI
    var errorDescription: String? {
        switch self {
        case .empty: return "Password cannot be empty."
        case .mismatch: return "Passwords do not match."
        case .tooShort(let min): return "Password must be at least \(min) characters long."
        case .missingUppercase: return "Add at least one uppercase letter."
        case .missingNumber: return "Add at least one number."
        case .missingSpecialCharacter: return "Add at least one special character."
        }
    }
}

struct PasswordValidator {
    static let minCount = 6
    
    // Using Void for Success because we only care if it's valid,
    // we don't need to return any data on success.
    static func validate(password: String, confirm: String) -> Result<Void, PasswordError> {
        if password.isEmpty {
            return .failure(.empty)
        }
        if password != confirm {
            return .failure(.mismatch)
        }
        if password.count < minCount {
            return .failure(.tooShort(min: minCount))
        }
        if password.rangeOfCharacter(from: .uppercaseLetters) == nil {
            return .failure(.missingUppercase)
        }
        if password.rangeOfCharacter(from: .decimalDigits) == nil {
            return .failure(.missingNumber)
        }
        let specialChars = CharacterSet(charactersIn: "!@#$%^&*()-_=+ ")
        if password.rangeOfCharacter(from: specialChars) == nil {
            return .failure(.missingSpecialCharacter)
        }
        
        return .success(())
    }
}
