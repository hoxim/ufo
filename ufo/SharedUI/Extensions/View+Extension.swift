//
//  View+Extension.swift
//  ufo
//
//  Created by Marcin Ryzko on 10/02/2026.
//

import SwiftUI

#if os(iOS)
typealias PlatformTextInputAutocapitalization = TextInputAutocapitalization
#else
enum PlatformTextInputAutocapitalization {
    case never
    case sentences
}
#endif

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

    @ViewBuilder
    func optionalPresentationDetents(_ detents: Set<PresentationDetent>?) -> some View {
        if let detents {
            self.presentationDetents(detents)
        } else {
            self
        }
    }

    @ViewBuilder
    func optionalMinimumFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        if width != nil || height != nil {
            self.frame(minWidth: width, minHeight: height)
        } else {
            self
        }
    }

    @ViewBuilder
    func platformTextInputAutocapitalization(_ value: PlatformTextInputAutocapitalization?) -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(value)
        #else
        self
        #endif
    }

    @ViewBuilder
    func decimalPadKeyboardIfSupported() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func emailKeyboardIfSupported() -> some View {
        #if os(iOS)
        self.keyboardType(.emailAddress)
        #else
        self
        #endif
    }

    @ViewBuilder
    func autocorrectionDisabledIfSupported() -> some View {
        #if os(iOS)
        self.autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func searchSubmitLabelIfSupported() -> some View {
        #if os(iOS)
        self.submitLabel(.search)
        #else
        self
        #endif
    }

    @ViewBuilder
    func activeEditModeIfSupported(_ isActive: Bool) -> some View {
        #if os(macOS)
        self
        #else
        if isActive {
            self.environment(\.editMode, .constant(.active))
        } else {
            self
        }
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
