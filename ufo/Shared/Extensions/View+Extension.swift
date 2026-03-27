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

    @ViewBuilder
    func hideTabBarIfSupported() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .tabBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func prominentFormTextInput() -> some View {
        #if os(macOS)
        self
            .textFieldStyle(.roundedBorder)
        #else
        self
        #endif
    }
}

extension ToolbarItemPlacement {
    static var platformTopBarLeading: ToolbarItemPlacement {
        #if os(macOS)
        .navigation
        #else
        .topBarLeading
        #endif
    }

    static var platformTopBarTrailing: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #else
        .topBarTrailing
        #endif
    }
}
