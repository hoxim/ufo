//
//  MembershipDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 03/02/2026.
//

import Foundation

struct MembershipDTO: Codable {
    let role: String
    let space: RemoteSpaceDTO?
}
