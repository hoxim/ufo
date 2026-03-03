//
//  Color+Extension.swift
//  ufo
//
//  Created by Marcin Ryzko on 10/02/2026.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {

    // MARK: - UFO Custom Colors
    static let ufoPrimary = Color("UFOPrimary")
    static let ufoSpacePurple = Color(red: 0.4, green: 0.2, blue: 0.6)
    
    // MARK: - System Adapters
    
    /// Returns secondary background color for iOS and macOS.
    static var systemSpaceedBackground: Color {
        #if os(iOS)
        return Color(uiColor: .secondarySystemBackground)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    /// Odpowiednik systemBackground
    static var systemBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    // MARK: - Helpers
    init(light: Color, dark: Color) {
        #if os(iOS)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #endif
    }

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8) / 255.0
            b = Double(value & 0x0000FF) / 255.0
        } else {
            r = 0.5
            g = 0.5
            b = 0.5
        }
        self.init(red: r, green: g, blue: b)
    }
}
