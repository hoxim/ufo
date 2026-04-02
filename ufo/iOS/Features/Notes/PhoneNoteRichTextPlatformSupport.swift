#if os(iOS)
import SwiftUI
import UIKit

extension PhoneNoteRichTextCodec {
    static func platformForegroundColor(for style: PhoneNoteBlockStyle) -> Any {
        style == .quote ? UIColor.secondaryLabel : UIColor.label
    }

    static var platformInlineCodeBackgroundColor: Any {
        UIColor.secondarySystemFill
    }

    static func platformFont(for style: PhoneNoteBlockStyle, bold: Bool, inlineCode: Bool, isPrefix: Bool) -> Any {
        let size: CGFloat
        switch style {
        case .heading:
            size = 30
        default:
            size = 19
        }

        if inlineCode && !isPrefix {
            return UIFont.monospacedSystemFont(ofSize: max(size - 1, 16), weight: bold ? .semibold : .regular)
        }

        let weight: UIFont.Weight = (bold || style == .heading) ? .bold : .regular
        var font = UIFont.systemFont(ofSize: size, weight: weight)

        if style == .quote && !isPrefix,
           let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
            font = UIFont(descriptor: descriptor, size: size)
        }

        return font
    }
}
#endif
