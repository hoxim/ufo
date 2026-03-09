//
//  TertiaryButtonStyle.swift
//  ufo
//
//  Created by Marcin Ryzko on 26/02/2026.
//

import SwiftUI

struct TertiaryButtonStyle: ButtonStyle {
    
    @Environment(\.isEnabled) private var isEnabled
    
    /// Handles make body.
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
    /// Handles ufo tertiary button.
    func ufoTertiaryButton() -> some View {
        self.buttonStyle(TertiaryButtonStyle())
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
