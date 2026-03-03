//
//  View+Extension.swift
//  ufo
//
//  Created by Marcin Ryzko on 10/02/2026.
//

import SwiftUI

extension View {
    /// Applies inline navigation title style on iOS only.
    @ViewBuilder
    /// Handles inline navigation title.
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
