//
//  Environment+Extension.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import SwiftUI

private struct SelectedSpaceIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var selectedSpaceID: UUID? {
        get { self[SelectedSpaceIDKey.self] }
        set { self[SelectedSpaceIDKey.self] = newValue }
    }
}
