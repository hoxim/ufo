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
    
    func createSpace(name: String, category: String) async throws
    func checkInvites(for email: String) async throws
    func acceptInvitation(_ invitation: SpaceInvitation) async throws
    func rejectInvitation(_ invitation: SpaceInvitation) async throws
}
