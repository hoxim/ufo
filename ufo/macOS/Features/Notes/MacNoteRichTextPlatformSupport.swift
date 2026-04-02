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
        let size: CGFloat
        switch style {
        case .heading:
            size = 30
        default:
            size = 18
        }

        if inlineCode && !isPrefix {
            return NSFont.monospacedSystemFont(ofSize: max(size - 1, 15), weight: bold ? .semibold : .regular)
        }

        let weight: NSFont.Weight = (bold || style == .heading) ? .bold : .regular
        var font = NSFont.systemFont(ofSize: size, weight: weight)

        if style == .quote && !isPrefix {
            let italicDescriptor = font.fontDescriptor.withSymbolicTraits(.italic)
            font = NSFont(descriptor: italicDescriptor, size: size) ?? font
        }

        return font
    }
}
#endif
