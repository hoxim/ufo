#if os(iOS)
import SwiftUI
import UIKit

extension PadNoteRichTextCodec {
    static func platformForegroundColor(for style: PadNoteBlockStyle) -> Any {
        style == .quote ? UIColor.secondaryLabel : UIColor.label
    }

    static var platformInlineCodeBackgroundColor: Any {
        UIColor.secondarySystemFill
    }

    static func platformFont(for style: PadNoteBlockStyle, bold: Bool, inlineCode: Bool, isPrefix: Bool) -> Any {
        let fontSize = PadNoteFontPreferences.fontSize
        let size: CGFloat
        switch style {
        case .heading:
            size = CGFloat(fontSize.headingSize(for: fontSize.padBodySize))
        default:
            size = CGFloat(fontSize.padBodySize)
        }

        if inlineCode && !isPrefix {
            return UIFont.monospacedSystemFont(ofSize: max(size - 1, 16), weight: bold ? .semibold : .regular)
        }

        let weight: UIFont.Weight = (bold || style == .heading) ? .bold : .regular
        var font = PadNoteFontPreferences.font(size: size, weight: weight)

        if style == .quote && !isPrefix,
           let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
            font = UIFont(descriptor: descriptor, size: size)
        }

        return font
    }
}

private enum PadNoteFontPreferences {
    static var fontSize: NoteEditorFontSizePreference {
        NoteEditorFontSizePreference(rawValue: UserDefaults.standard.string(forKey: AppPreferences.noteEditorFontSizeKey) ?? "") ?? .standard
    }

    static var fontDesign: NoteEditorFontDesign {
        NoteEditorFontDesign(rawValue: UserDefaults.standard.string(forKey: AppPreferences.noteEditorFontDesignKey) ?? "") ?? .system
    }

    static func font(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        switch fontDesign {
        case .monospaced:
            return UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .rounded:
            return designedSystemFont(size: size, weight: weight, design: .rounded)
        case .serif:
            return designedSystemFont(size: size, weight: weight, design: .serif)
        case .system:
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
    }

    private static func designedSystemFont(size: CGFloat, weight: UIFont.Weight, design: UIFontDescriptor.SystemDesign) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = font.fontDescriptor.withDesign(design) else {
            return font
        }
        return UIFont(descriptor: descriptor, size: size)
    }
}
#endif
