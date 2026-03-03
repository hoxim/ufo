import Foundation
import Observation

@Observable
@MainActor
class InviteViewModel {
    var email: String = ""
    var isProcessing: Bool = false
    var message: String?
    var showMessage: Bool = false
    var isSuccess: Bool = false
    
    private let spaceRepository: SpaceRepository
    private let spaceId: UUID
    
    init(spaceRepository: SpaceRepository, spaceId: UUID) {
        self.spaceRepository = spaceRepository
        self.spaceId = spaceId
    }
    
    /// Handles send invite.
    func sendInvite() async {
        guard !email.isEmpty else { return }
        
        isProcessing = true
        isSuccess = false
        defer { isProcessing = false }
        
        do {
            try await spaceRepository.inviteMember(email: email, spaceId: spaceId)
            message = String(localized: "Invitation sent to \(email)!")
            isSuccess = true
            showMessage = true
            email = ""
        } catch {
            isSuccess = false
            message = String(localized: "Failed to send: \(error.localizedDescription)")
            showMessage = true
        }
    }
}
