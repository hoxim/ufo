//
//  UfoTextField.swift
//  ufo
//
//  Created by Marcin Ryzko on 26/02/2026.
//

import SwiftUI

struct UfoTextField: View {
    
    let title: LocalizedStringKey
    @Binding var text: String
    var isError: Bool = false
    
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled
    
    var body: some View {
        TextField(title, text: $text)
            .padding()
            .background(Color.ufoTextInputBackground)
            .foregroundStyle(Color.ufoTextInputForeground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .focused($isFocused)
    }
    
    private var borderColor: Color {
        if !isEnabled { return .gray.opacity(0.3) }
        if isError { return .red }
        if isFocused { return .primaryButtonBackground }
        return Color.ufoTextInputBorder
    }
}

#Preview("TextField - Light") {
    @Previewable @State var email: String = "aSas"
    @Previewable @State var isError: Bool = true
    VStack(spacing: 20) {
        UfoTextField(title: "auth.login.email", text: $email)
        UfoTextField(title: "auth.login.email", text: $email).disabled(true)
        UfoTextField(title: "auth.login.email", text: $email, isError: true);
    }
}

#Preview("TextField - Dark") {
    @Previewable @State var email: String = "asdasd"
    VStack(spacing: 20) {
        UfoTextField(title: "auth.login.email", text: $email)
        UfoTextField(title: "auth.login.email", text: $email).disabled(true)
        UfoTextField(title: "auth.login.email", text: $email, isError: true);
    }.preferredColorScheme(.dark)
}

