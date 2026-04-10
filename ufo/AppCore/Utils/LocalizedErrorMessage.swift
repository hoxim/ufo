import Foundation

func localizedErrorMessage(_ key: String, error: Error) -> String {
    String(format: NSLocalizedString(key, comment: ""), error.localizedDescription)
}
