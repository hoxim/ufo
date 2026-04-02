import SwiftUI

enum AppTheme {
    enum Colors {
        static let canvas = Color(
            light: Color(hex: "#F5F6F8"),
            dark: Color(hex: "#2B3035")
        )

        static let sidebar = Color(
            light: Color(hex: "#F1F3F5"),
            dark: Color(hex: "#20252B")
        )

        static let surface = Color(
            light: .white,
            dark: Color(hex: "#30353B")
        )

        static let elevatedSurface = Color(
            light: .white,
            dark: Color(hex: "#383E45")
        )

        static let mutedFill = Color(
            light: Color.black.opacity(0.04),
            dark: Color.white.opacity(0.055)
        )

        static let divider = Color(
            light: Color.black.opacity(0.08),
            dark: Color.white.opacity(0.10)
        )
    }
}

private struct AppScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        ZStack {
            AppTheme.Colors.canvas
                .ignoresSafeArea()

            content
        }
        #else
        content
        #endif
    }
}

private struct AppPrimaryListChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.canvas)
        #else
        content
        #endif
    }
}

extension View {
    func appScreenBackground() -> some View {
        modifier(AppScreenBackgroundModifier())
    }

    func appPrimaryListChrome() -> some View {
        modifier(AppPrimaryListChromeModifier())
    }

    func appSurfaceBackground() -> some View {
        background(AppTheme.Colors.canvas)
    }
}
