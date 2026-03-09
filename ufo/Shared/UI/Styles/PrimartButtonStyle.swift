//
//  PrimartButtonStyle.swift
//  ufo
//
//  Created by Marcin Ryzko on 26/02/2026.
//

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    
    @Environment(\.isEnabled) private var isEnabled
    
    /// Handles make body.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(isEnabled
                        ? Color.primaryButtonBackground
                        : Color.disabledButtonBackground)
            .foregroundStyle(isEnabled
                             ? Color.primaryButtonText
                             : Color.disabledButtonText)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension View {
    /// Handles ufo primary button.
    func ufoPrimaryButton() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
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
    Card{
        Button("common.preview.button.primary") {}.ufoPrimaryButton()
        Button("common.preview.button.secondary") {}.ufoSecondaryButton()
        Button("common.preview.button.tertiary") {}.ufoTertiaryButton()
        Button("common.preview.button.destructive") {}.ufoDestructiveButton()
        Button("common.preview.button.disabled") {}.ufoPrimaryButton().disabled(true)
    }

    .preferredColorScheme(.dark)
}
