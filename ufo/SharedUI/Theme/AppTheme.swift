import SwiftUI

enum AppTheme {
    enum Colors {
        // Full-screen app background behind the main content area.
        static let canvas = Color(
            light: Color(hex: "#F5F6F8"),
            dark: Color(hex: "#24292C")
        )

        // Sidebar and split-view navigation background.
        static let sidebar = Color(
            light: Color(hex: "#F1F3F5"),
            dark: Color(hex: "#20252B")
        )

        // Default solid card and form background.
        static let card = Color(
            light: .white,
            dark: Color(hex: "#30353B")
        )

        // Slightly raised surface for popovers, elevated panels, and overlays.
        static let elevatedCard = Color(
            light: .white,
            dark: Color(hex: "#383E45")
        )

        // Neutral filled controls like pills and segmented buttons.
        static let mutedFill = Color(
            light: Color(hex: "#EDEEF0"),
            dark: Color(hex: "#363C42")
        )

        // Selected backgrounds for primary rows in split-view content columns.
        static let listSelection = mutedFill

        // Dividers and subtle borders between sections.
        static let divider = Color(
            light: Color(hex: "#E1E3E6"),
            dark: Color(hex: "#454C54")
        )

        // Backward-compatible aliases for existing screens.
        static let surface = card
        static let elevatedSurface = elevatedCard
    }

    enum FeatureColors {
        static let homeAccent = Color(
            light: Color(hex: "#6366F1"),
            dark: Color(hex: "#8B93FF")
        )

        static let searchAccent = Color(
            light: Color(hex: "#0F766E"),
            dark: Color(hex: "#4FD1C5")
        )

        static let missionsAccent = Color(
            light: Color(hex: "#DD6B20"),
            dark: Color(hex: "#F6AD55")
        )

        static let notesAccent = Color(
            light: Color(hex: "#2563EB"),
            dark: Color(hex: "#60A5FA")
        )

        static let listsAccent = Color(
            light: Color(hex: "#DB2777"),
            dark: Color(hex: "#F472B6")
        )

        static let incidentsAccent = Color(
            light: Color(hex: "#DC2626"),
            dark: Color(hex: "#F87171")
        )

        static let routinesAccent = Color(
            light: Color(hex: "#16A34A"),
            dark: Color(hex: "#4ADE80")
        )

        static let budgetAccent = Color(
            light: Color(hex: "#9333EA"),
            dark: Color(hex: "#C084FC")
        )

        static let messagesAccent = Color(
            light: Color(hex: "#0891B2"),
            dark: Color(hex: "#67E8F9")
        )

        static let locationsAccent = Color(
            light: Color(hex: "#059669"),
            dark: Color(hex: "#34D399")
        )

        static let rolesAccent = Color(
            light: Color(hex: "#7C3AED"),
            dark: Color(hex: "#A78BFA")
        )

        static let peopleAccent = Color(
            light: Color(hex: "#EA580C"),
            dark: Color(hex: "#FB923C")
        )

        static let spacesAccent = Color(
            light: Color(hex: "#475569"),
            dark: Color(hex: "#94A3B8")
        )

        static let notificationsAccent = Color(
            light: Color(hex: "#D97706"),
            dark: Color(hex: "#FBBF24")
        )
    }

    enum ChartColors {
        static let income = Color(
            light: Color(hex: "#10B981"),
            dark: Color(hex: "#34D399")
        )

        static let expense = Color(
            light: Color(hex: "#EF4444"),
            dark: Color(hex: "#F87171")
        )

        static let balance = Color(
            light: Color(hex: "#3B82F6"),
            dark: Color(hex: "#60A5FA")
        )

        static let projection = Color(
            light: Color(hex: "#F59E0B"),
            dark: Color(hex: "#FBBF24")
        )

        static let categorySeries: [Color] = [
            Color(light: Color(hex: "#8B5CF6"), dark: Color(hex: "#C084FC")),
            Color(light: Color(hex: "#EC4899"), dark: Color(hex: "#F472B6")),
            Color(light: Color(hex: "#14B8A6"), dark: Color(hex: "#2DD4BF")),
            Color(light: Color(hex: "#F97316"), dark: Color(hex: "#FB923C")),
            Color(light: Color(hex: "#0EA5E9"), dark: Color(hex: "#38BDF8"))
        ]
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
