//
//  String+Error.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import Foundation

extension String: @retroactive Error {}
extension String: @retroactive LocalizedError {
    public var errorDescription: String? { return self }
}
