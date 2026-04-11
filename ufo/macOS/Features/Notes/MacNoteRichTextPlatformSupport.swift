#if os(macOS)
import SwiftUI
import AppKit

extension MacNoteRichTextCodec {
    static func platformForegroundColor(for style: MacNoteBlockStyle) -> Any {
        style == .quote ? NSColor.secondaryLabelColor : NSColor.labelColor
    }

    static var platformInlineCodeBackgroundColor: Any {
        NSColor.controlAccentColor.withAlphaComponent(0.12)
    }

    static func platformFont(for style: MacNoteBlockStyle, bold: Bool, inlineCode: Bool, isPrefix: Bool) -> Any {
        let fontSize = MacNoteFontPreferences.fontSize
        let size: CGFloat
        switch style {
        case .heading:
            size = CGFloat(fontSize.headingSize(for: fontSize.macBodySize))
        default:
            size = CGFloat(fontSize.macBodySize)
        }

        if inlineCode && !isPrefix {
            return NSFont.monospacedSystemFont(ofSize: max(size - 1, 15), weight: bold ? .semibold : .regular)
        }

        let weight: NSFont.Weight = (bold || style == .heading) ? .bold : .regular
        var font = MacNoteFontPreferences.font(size: size, weight: weight)

        if style == .quote && !isPrefix {
            let italicDescriptor = font.fontDescriptor.withSymbolicTraits(.italic)
            font = NSFont(descriptor: italicDescriptor, size: size) ?? font
        }

        return font
    }
}

private enum MacNoteFontPreferences {
    static var fontSize: NoteEditorFontSizePreference {
        NoteEditorFontSizePreference(rawValue: UserDefaults.standard.string(forKey: AppPreferences.noteEditorFontSizeKey) ?? "") ?? .standard
    }

    static var fontDesign: NoteEditorFontDesign {
        NoteEditorFontDesign(rawValue: UserDefaults.standard.string(forKey: AppPreferences.noteEditorFontDesignKey) ?? "") ?? .system
    }

    static func font(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        switch fontDesign {
        case .monospaced:
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .serif:
            return serifFont(size: size, weight: weight)
        case .rounded, .system:
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
    }

    private static func serifFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let preferredName = weight == .bold || weight == .semibold ? "NewYork-Bold" : "NewYork-Regular"
        return NSFont(name: preferredName, size: size)
            ?? NSFont(name: "Times New Roman", size: size)
            ?? NSFont.systemFont(ofSize: size, weight: weight)
    }
}
#endif
