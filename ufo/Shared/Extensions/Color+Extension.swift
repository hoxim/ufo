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
    // (Twoje istniejące kolory)
    static let ufoPrimary = Color("UFOPrimary") // Upewnij się, że masz ten Asset, lub użyj .blue
    static let ufoSpacePurple = Color(red: 0.4, green: 0.2, blue: 0.6)
    
    // MARK: - System Adapters (Naprawa błędu)
    
    /// Odpowiednik secondarySystemBackground działający na iOS i macOS
    static var systemSpaceedBackground: Color {
        #if os(iOS)
        return Color(uiColor: .secondarySystemBackground)
        #else
        // Na macOS używamy koloru tła okna lub kontrolki
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
    
    // Twój pomocniczy init
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
}
