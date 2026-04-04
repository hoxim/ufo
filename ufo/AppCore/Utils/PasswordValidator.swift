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
        case .empty: return String(localized: "password.error.empty")
        case .mismatch: return String(localized: "password.error.mismatch")
        case .tooShort(let min): return String(format: String(localized: "password.error.tooShort"), min)
        case .missingUppercase: return String(localized: "password.error.missingUppercase")
        case .missingNumber: return String(localized: "password.error.missingNumber")
        case .missingSpecialCharacter: return String(localized: "password.error.missingSpecialCharacter")
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
