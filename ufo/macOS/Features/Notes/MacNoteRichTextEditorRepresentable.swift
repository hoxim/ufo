#if os(macOS)
import SwiftUI

struct MacNoteRichTextEditorRepresentable: View {
    @Binding var attributedText: NSAttributedString
    @Binding var selectedRange: NSRange
    let isEditable: Bool

    var body: some View {
        TextEditor(text: plainTextBinding)
            .font(.body)
            .scrollContentBackground(.hidden)
            .disabled(!isEditable)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .onAppear {
                selectedRange = NSRange(location: attributedText.length, length: 0)
            }
    }

    private var plainTextBinding: Binding<String> {
        Binding(
            get: { attributedText.string },
            set: { newValue in
                attributedText = MacNoteRichTextCodec.makeEditorText(from: newValue)
                selectedRange = NSRange(location: attributedText.length, length: 0)
            }
        )
    }
}
#endif
