//
//  RemoteSpaceDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 03/02/2026.
//

import Foundation

struct RemoteSpaceDTO: Codable {
    let id: UUID
    let name: String
    let inviteCode: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case inviteCode = "invite_code"
    }
}
