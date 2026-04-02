#if os(iOS)
import SwiftUI
import UIKit

struct PhoneNoteRichTextEditorRepresentable: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var selectedRange: NSRange
    let isEditable: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = UIEdgeInsets(top: 18, left: 14, bottom: 18, right: 14)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.attributedText = attributedText
        return textView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let targetWidth = proposal.width ?? max(uiView.bounds.width, 0)
        guard targetWidth > 0 else { return nil }
        let fittingSize = CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
        let size = uiView.sizeThatFits(fittingSize)
        return CGSize(width: targetWidth, height: size.height)
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.isEditable = isEditable

        if !uiView.attributedText.isEqual(attributedText) {
            let wasFirstResponder = uiView.isFirstResponder
            uiView.attributedText = attributedText
            if wasFirstResponder {
                uiView.becomeFirstResponder()
            }
        }

        let safeLocation = min(max(selectedRange.location, 0), uiView.attributedText.length)
        let safeLength = min(max(selectedRange.length, 0), max(uiView.attributedText.length - safeLocation, 0))
        let safeRange = NSRange(location: safeLocation, length: safeLength)

        if uiView.selectedRange != safeRange {
            uiView.selectedRange = safeRange
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PhoneNoteRichTextEditorRepresentable

        init(_ parent: PhoneNoteRichTextEditorRepresentable) {
            self.parent = parent
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard parent.isEditable, text == "\n", range.length == 0 else { return true }

            let mutable = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
            guard mutable.length > 0 else { return true }

            let nsString = mutable.string as NSString
            let safeLocation = min(max(range.location, 0), mutable.length)
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: min(safeLocation, max(mutable.length - 1, 0)), length: 0))
            let style = PhoneNoteRichTextCodec.blockStyle(in: mutable, at: paragraphRange.location)

            guard style.supportsContinuation else { return true }

            let paragraph = NSMutableAttributedString(attributedString: mutable.attributedSubstring(from: paragraphRange))
            let hasTrailingNewline = paragraph.string.hasSuffix("\n")
            if hasTrailingNewline {
                paragraph.deleteCharacters(in: NSRange(location: max(paragraph.length - 1, 0), length: 1))
            }

            let contentText = PhoneNoteRichTextCodec.contentText(for: paragraph).trimmingCharacters(in: .whitespacesAndNewlines)

            if contentText.isEmpty {
                mutable.replaceCharacters(in: paragraphRange, with: NSAttributedString(string: "\n", attributes: PhoneNoteRichTextCodec.attributes(for: .body)))
                textView.attributedText = mutable
                textView.selectedRange = NSRange(location: paragraphRange.location, length: 0)
                textViewDidChange(textView)
                textViewDidChangeSelection(textView)
                return false
            }

            let insertion = NSMutableAttributedString(
                string: "\n" + style.editorPrefix,
                attributes: PhoneNoteRichTextCodec.attributes(for: style)
            )
            if style.editorPrefixLength > 0 {
                insertion.setAttributes(
                    PhoneNoteRichTextCodec.attributes(for: style, isPrefix: true),
                    range: NSRange(location: 1, length: style.editorPrefixLength)
                )
            }

            mutable.replaceCharacters(in: range, with: insertion)
            let affectedRange = NSRange(location: paragraphRange.location, length: paragraphRange.length + insertion.length)
            PhoneNoteRichTextCodec.restyleParagraphsIntersecting(in: mutable, range: affectedRange)

            textView.attributedText = mutable
            textView.selectedRange = NSRange(location: safeLocation + insertion.length, length: 0)
            textViewDidChange(textView)
            textViewDidChangeSelection(textView)
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = textView.attributedText ?? NSAttributedString(string: "")
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
        }
    }
}
#endif
