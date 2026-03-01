import Foundation
import Observation

@MainActor
@Observable
final class AuthStore {
    enum State: Equatable {
        case checkingSession
        case signedOut
        case bootstrapping
        case ready
    }

    private let authRepository: AuthRepository
    private let spaceRepository: SpaceRepository

    var state: State = .checkingSession
    var errorMessage: String?

    init(authRepository: AuthRepository, spaceRepository: SpaceRepository) {
        self.authRepository = authRepository
        self.spaceRepository = spaceRepository
    }

    var isLoggedIn: Bool {
        authRepository.isLoggedIn
    }

    var currentUser: UserProfile? {
        authRepository.currentUser
    }

    func bootstrap() async {
        state = .checkingSession
        errorMessage = nil

        await authRepository.checkAuthStatus()
        guard authRepository.isLoggedIn else {
            state = .signedOut
            return
        }

        await loadUserContext()
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        state = .checkingSession

        do {
            try await authRepository.signIn(email: email, password: password)
            await loadUserContext()
        } catch {
            state = .signedOut
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async throws {
        try await authRepository.signUp(email: email, password: password)
    }

    func signOut() async {
        await authRepository.signOut()
        spaceRepository.selectedSpace = nil
        state = .signedOut
    }

    func refreshProfileAndSpaces() async {
        guard let userId = authRepository.currentUser?.id else { return }
        do {
            try await authRepository.fetchUserProfile(id: userId)
            await ensureSpaceSelection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadUserContext() async {
        state = .bootstrapping

        do {
            guard let userId = authRepository.currentUser?.id else {
                state = .signedOut
                return
            }

            try await authRepository.fetchUserProfile(id: userId)

            var spaces = authRepository.currentUser?.memberships.compactMap(\.space) ?? []
            try await spaceRepository.ensurePersonalSpaceIfNeeded(for: spaces)

            if spaces.isEmpty {
                try await authRepository.fetchUserProfile(id: userId)
                spaces = authRepository.currentUser?.memberships.compactMap(\.space) ?? []
            }

            spaceRepository.restoreLastSelectedSpace(from: spaces)
            if spaceRepository.selectedSpace == nil {
                spaceRepository.selectFirstSpace(from: spaces)
            }

            state = .ready
        } catch {
            state = .signedOut
            errorMessage = error.localizedDescription
        }
    }

    private func ensureSpaceSelection() async {
        let spaces = authRepository.currentUser?.memberships.compactMap(\.space) ?? []
        spaceRepository.restoreLastSelectedSpace(from: spaces)
        if spaceRepository.selectedSpace == nil {
            spaceRepository.selectFirstSpace(from: spaces)
        }
    }
}
