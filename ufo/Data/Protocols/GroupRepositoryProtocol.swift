//
//  Untitled.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//



protocol GroupRepositoryProtocol: AnyObject {
    var userGroup: Group? { get }
    var pendingInvitation: GroupInvitation? { get }
    var isBusy: Bool { get }
    
    func createGroup(name: String, category: String) async throws
    func checkInvites(for email: String) async throws
    func acceptInvitation(_ invitation: GroupInvitation) async throws
    func rejectInvitation(_ invitation: GroupInvitation) async throws
}
