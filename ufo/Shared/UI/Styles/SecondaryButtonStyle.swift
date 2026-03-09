//
//  SecondaryButtonStyle.swift
//  ufo
//
//  Created by Marcin Ryzko on 26/02/2026.
//

import SwiftUI

struct SecondaryButtonStyle: ButtonStyle {
    
    @Environment(\.isEnabled) private var isEnabled
    
    /// Handles make body.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(isEnabled
                        ? Color.secondaryButtonBackground
                        : Color.disabledButtonBackground)
            .foregroundStyle(isEnabled
                             ? Color.secondaryButtonText
                             : Color.disabledButtonText)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension View {
    /// Handles ufo secondary button.
    func ufoSecondaryButton() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
}

#Preview("All Buttons - Light") {
    VStack(spacing: 20) {
        Button("common.preview.button.primary") {}.ufoPrimaryButton()
        Button("common.preview.button.secondary") {}.ufoSecondaryButton()
        Button("common.preview.button.tertiary") {}.ufoTertiaryButton()
        Button("common.preview.button.destructive") {}.ufoDestructiveButton()
        Button("common.preview.button.disabled") {}.ufoPrimaryButton().disabled(true)
    }
    .padding()
}

#Preview("All Buttons - Dark") {
    VStack(spacing: 20) {
        Button("common.preview.button.primary") {}.ufoPrimaryButton()
        Button("common.preview.button.secondary") {}.ufoSecondaryButton()
        Button("common.preview.button.tertiary") {}.ufoTertiaryButton()
        Button("common.preview.button.destructive") {}.ufoDestructiveButton()
        Button("common.preview.button.disabled") {}.ufoPrimaryButton().disabled(true)
    }
    .padding()
    .preferredColorScheme(.dark)
}
