import Foundation

func localizedErrorMessage(_ key: String, error: Error) -> String {
    String(format: String(localized: key), error.localizedDescription)
}

