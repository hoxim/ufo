//
//  Untitled.swift
//  ufo
//
//  Created by Marcin Ryzko on 26/02/2026.
//

import SwiftUI

struct DestructiveButtonStyle: ButtonStyle {
    
    @Environment(\.isEnabled) private var isEnabled
    
    /// Handles make body.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(isEnabled
                        ? Color.destructiveButtonBackground
                        : Color.disabledButtonBackground)
            .foregroundStyle(isEnabled
                             ? Color.destructiveButtonText
                             : Color.disabledButtonText)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension View {
    /// Handles ufo destructive button.
    func ufoDestructiveButton() -> some View {
        self.buttonStyle(DestructiveButtonStyle())
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
