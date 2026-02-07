//
//  Color+Extension.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import SwiftUI

extension Color {

    static let ufoBackground = Color(light: .white, dark: Color(red: 0.05, green: 0.05, blue: 0.1))
    static let ufoCardBackground = Color(light: Color(white: 0.95), dark: Color(white: 0.15))

    static let ufoPrimary = Color("UFOPrimary") 
    static let ufoSpacePurple = Color(red: 0.4, green: 0.2, blue: 0.6)

    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        // Dla macOS (jeśli budujesz apkę natywną na Maca)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #endif
    }
}
