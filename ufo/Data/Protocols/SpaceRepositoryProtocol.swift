//
//  Untitled.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

protocol SpaceRepositoryProtocol: AnyObject {
    var userSpace: Space? { get }
    var pendingInvitation: SpaceInvitation? { get }
    var isBusy: Bool { get }
    
    /// Creates space.
    func createSpace(name: String, category: String) async throws
    /// Checks invites.
    func checkInvites(for email: String) async throws
    /// Handles accept invitation.
    func acceptInvitation(_ invitation: SpaceInvitation) async throws
    /// Handles reject invitation.
    func rejectInvitation(_ invitation: SpaceInvitation) async throws
}
