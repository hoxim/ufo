//
//  TertiaryButtonStyle.swift
//  ufo
//
//  Created by Marcin Ryzko on 26/02/2026.
//

import SwiftUI

struct TertiaryButtonStyle: ButtonStyle {
    
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 10)
            .foregroundStyle(isEnabled
                             ? Color.tertiaryButtonText
                             : Color.disabledButtonText)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension View {
    func ufoTertiaryButton() -> some View {
        self.buttonStyle(TertiaryButtonStyle())
    }
}

#Preview("All Buttons - Light") {
    VStack(spacing: 20) {
        Button("Primary") {}.ufoPrimaryButton()
        Button("Secondary") {}.ufoSecondaryButton()
        Button("Tertiary") {}.ufoTertiaryButton()
        Button("Destructive") {}.ufoDestructiveButton()
        Button("Disabled") {}.ufoPrimaryButton().disabled(true)
    }
    .padding()
}

#Preview("All Buttons - Dark") {
    VStack(spacing: 20) {
        Button("Primary") {}.ufoPrimaryButton()
        Button("Secondary") {}.ufoSecondaryButton()
        Button("Tertiary") {}.ufoTertiaryButton()
        Button("Destructive") {}.ufoDestructiveButton()
        Button("Disabled") {}.ufoPrimaryButton().disabled(true)
    }
    .padding()
    .preferredColorScheme(.dark)
}
