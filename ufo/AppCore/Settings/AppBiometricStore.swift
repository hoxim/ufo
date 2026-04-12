#if os(iOS)

import LocalAuthentication
import Observation

@MainActor
@Observable
final class AppBiometricStore {
    private(set) var isLocked = false
    private(set) var isAuthenticating = false
    var authError: String?

    private var backgroundedAt: Date?

    // MARK: - Biometry info

    var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var biometrySystemImage: String {
        switch biometryType {
        case .faceID:   "faceid"
        case .touchID:  "touchid"
        case .opticID:  "opticid"
        default:        "lock.fill"
        }
    }

    var biometryLabel: String {
        switch biometryType {
        case .faceID:  "Face ID"
        case .touchID: "Touch ID"
        default:       String(localized: "settings.security.biometric.generic")
        }
    }

    var isBiometryAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // MARK: - Lock lifecycle

    func lockIfNeeded(preferences: AppPreferences) {
        guard preferences.biometricLockEnabled, isBiometryAvailable else { return }
        isLocked = true
    }

    func handleBackground() {
        guard isLocked == false else { return }
        backgroundedAt = Date()
    }

    func handleForeground(preferences: AppPreferences) {
        guard preferences.biometricLockEnabled, isBiometryAvailable, !isLocked else { return }
        guard let bg = backgroundedAt else { return }
        defer { backgroundedAt = nil }

        let elapsed = Date().timeIntervalSince(bg)
        let timeout = preferences.autoLockTimeout

        switch timeout {
        case .immediately:
            isLocked = true
        case .never:
            break
        default:
            if elapsed >= Double(timeout.rawValue) {
                isLocked = true
            }
        }
    }

    // MARK: - Authentication

    func authenticate() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authError = nil

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            authError = error?.localizedDescription ?? String(localized: "biometric.error.unavailable")
            isAuthenticating = false
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: String(localized: "biometric.unlock.reason")
            )
            if success {
                isLocked = false
            }
        } catch let laError as LAError where laError.code == .userCancel {
            // User cancelled — keep locked, no error message
        } catch {
            authError = error.localizedDescription
        }

        isAuthenticating = false
    }
}

#endif
