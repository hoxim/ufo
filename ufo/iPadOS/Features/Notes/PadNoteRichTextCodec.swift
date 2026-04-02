#if os(iOS)

import Foundation
import SwiftUI

enum PadNoteInlineStyle {
    case bold
    case inlineCode
}

enum PadNoteBlockStyle: String {
    case body
    case heading
    case bullet
    case checklistUnchecked
    case quote

    var editorPrefix: String {
        switch self {
        case .body, .heading:
            return ""
        case .bullet:
            return "• "
        case .checklistUnchecked:
            return "☐ "
        case .quote:
            return "▌ "
        }
    }

    var markdownPrefix: String {
        switch self {
        case .body:
            return ""
        case .heading:
            return "## "
        case .bullet:
            return "- "
        case .checklistUnchecked:
            return "- [ ] "
        case .quote:
            return "> "
        }
    }

    var editorPrefixLength: Int {
        editorPrefix.utf16.count
    }

    var supportsContinuation: Bool {
        switch self {
        case .bullet, .checklistUnchecked, .quote:
            return true
        case .body, .heading:
            return false
        }
    }
}

enum PadNoteRichTextCodec {
    static func makeEditorText(from markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let (style, content) = blockStyleAndContent(for: line)
            result.append(makeParagraph(content: content, style: style))

            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: attributes(for: style)))
            }
        }

        if result.length == 0 {
            return NSAttributedString(string: "", attributes: attributes(for: .body))
        }

        return result
    }

    static func makeMarkdown(from attributedText: NSAttributedString) -> String {
        guard attributedText.length > 0 else { return "" }

        let fullString = attributedText.string as NSString
        var lines: [String] = []
        var location = 0

        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            let paragraph = NSMutableAttributedString(attributedString: attributedText.attributedSubstring(from: paragraphRange))
            let hasTrailingNewline = paragraph.string.hasSuffix("\n")

            if hasTrailingNewline {
                paragraph.deleteCharacters(in: NSRange(location: max(paragraph.length - 1, 0), length: 1))
            }

            let style = blockStyle(in: paragraph, at: 0)
            removeEditorPrefix(from: paragraph)
            lines.append(style.markdownPrefix + inlineMarkdown(from: paragraph))

            location = paragraphRange.location + paragraphRange.length
        }

        return lines.joined(separator: "\n")
    }

    static func paragraphRangesCovering(selection: NSRange, in text: NSAttributedString) -> [NSRange] {
        let nsString = text.string as NSString
        guard nsString.length > 0 else { return [NSRange(location: 0, length: 0)] }

        let safeLocation = min(max(selection.location, 0), nsString.length)
        let safeLength = min(max(selection.length, 0), max(nsString.length - safeLocation, 0))

        let firstParagraph = nsString.paragraphRange(for: NSRange(location: min(safeLocation, max(nsString.length - 1, 0)), length: 0))
        var combined = firstParagraph

        if safeLength > 0 {
            let lastTouchedLocation = max(safeLocation + safeLength - 1, safeLocation)
            let clampedLastTouchedLocation = min(lastTouchedLocation, max(nsString.length - 1, 0))
            combined = NSUnionRange(combined, nsString.paragraphRange(for: NSRange(location: clampedLastTouchedLocation, length: 0)))

            let selectedSubstring = nsString.substring(with: NSRange(location: safeLocation, length: safeLength))
            let trailingNewlineCount = selectedSubstring.reversed().prefix { $0 == "\n" }.count
            if trailingNewlineCount > 0 {
                var cursor = combined.location + combined.length
                for _ in 0..<trailingNewlineCount {
                    guard cursor < nsString.length else { break }
                    let nextParagraph = nsString.paragraphRange(for: NSRange(location: cursor, length: 0))
                    combined = NSUnionRange(combined, nextParagraph)
                    cursor = nextParagraph.location + nextParagraph.length
                }
            }
        }

        var ranges: [NSRange] = []
        var cursor = combined.location
        let end = combined.location + combined.length
        while cursor < end {
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: cursor, length: 0))
            ranges.append(paragraphRange)
            cursor = paragraphRange.location + max(paragraphRange.length, 1)
        }

        return ranges
    }

    static func effectiveInlineRange(for selectedRange: NSRange, in text: NSAttributedString) -> NSRange {
        guard text.length > 0 else { return NSRange(location: 0, length: 0) }
        if selectedRange.length > 0 {
            return selectedRange
        }

        let string = text.string as NSString
        let clampedLocation = min(max(selectedRange.location, 0), max(string.length - 1, 0))
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)

        var start = clampedLocation
        while start > 0 {
            let value = string.character(at: start - 1)
            if let scalar = UnicodeScalar(Int(value)), separators.contains(scalar) {
                break
            }
            start -= 1
        }

        var end = clampedLocation
        while end < string.length {
            let value = string.character(at: end)
            if let scalar = UnicodeScalar(Int(value)), separators.contains(scalar) {
                break
            }
            end += 1
        }

        return NSRange(location: start, length: max(end - start, 0))
    }

    static func isInlineStyleFullyEnabled(_ style: PadNoteInlineStyle, in text: NSMutableAttributedString, range: NSRange) -> Bool {
        guard range.length > 0 else { return false }
        let key = style == .bold ? NSAttributedString.Key.padNoteBold : NSAttributedString.Key.padNoteInlineCode
        var isEnabledEverywhere = true

        text.enumerateAttribute(key, in: range) { value, _, stop in
            if (value as? Bool) != true {
                isEnabledEverywhere = false
                stop.pointee = true
            }
        }

        return isEnabledEverywhere
    }

    static func setInlineStyle(_ style: PadNoteInlineStyle, enabled: Bool, in text: NSMutableAttributedString, range: NSRange) {
        let key = style == .bold ? NSAttributedString.Key.padNoteBold : NSAttributedString.Key.padNoteInlineCode
        text.addAttribute(key, value: enabled, range: range)
        restyleParagraphsIntersecting(in: text, range: range)
    }

    static func restyleParagraph(in text: NSMutableAttributedString, range: NSRange, blockStyle: PadNoteBlockStyle) {
        guard range.length >= 0 else { return }
        text.addAttribute(.padNoteBlockStyle, value: blockStyle.rawValue, range: range)

        if blockStyle.editorPrefixLength > 0, text.string.count >= blockStyle.editorPrefixLength {
            let prefixRange = NSRange(location: range.location, length: min(blockStyle.editorPrefixLength, range.length))
            if prefixRange.length > 0 {
                text.setAttributes(attributes(for: blockStyle, bold: false, inlineCode: false, isPrefix: true), range: prefixRange)
            }
        }

        let contentRange = NSRange(
            location: range.location + blockStyle.editorPrefixLength,
            length: max(range.length - blockStyle.editorPrefixLength, 0)
        )

        guard contentRange.length > 0 else { return }

        text.enumerateAttributes(in: contentRange) { attrs, runRange, _ in
            let isBold = (attrs[.padNoteBold] as? Bool) == true
            let isCode = (attrs[.padNoteInlineCode] as? Bool) == true
            text.setAttributes(attributes(for: blockStyle, bold: isBold, inlineCode: isCode), range: runRange)
        }
    }

    static func restyleParagraphsIntersecting(in text: NSMutableAttributedString, range: NSRange) {
        let nsString = text.string as NSString
        let safeLocation = min(max(range.location, 0), nsString.length)
        let safeLength = min(max(range.length, 0), max(nsString.length - safeLocation, 0))
        let safeRange = NSRange(location: safeLocation, length: safeLength)
        let firstParagraph = nsString.paragraphRange(for: NSRange(location: safeRange.location, length: 0))
        let lastLocation = min(max(safeRange.location + max(safeRange.length - 1, 0), 0), max(nsString.length - 1, 0))
        let lastParagraph = nsString.paragraphRange(for: NSRange(location: lastLocation, length: 0))
        let combined = NSUnionRange(firstParagraph, lastParagraph)

        var cursor = combined.location
        while cursor < combined.location + combined.length {
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: cursor, length: 0))
            let hasTrailingNewline = nsString.substring(with: paragraphRange).hasSuffix("\n")
            let effectiveRange = NSRange(
                location: paragraphRange.location,
                length: hasTrailingNewline ? max(paragraphRange.length - 1, 0) : paragraphRange.length
            )
            let style = blockStyle(in: text, at: effectiveRange.location)
            restyleParagraph(in: text, range: effectiveRange, blockStyle: style)
            cursor = paragraphRange.location + max(paragraphRange.length, 1)
        }
    }

    static func blockStyle(in text: NSAttributedString, at location: Int) -> PadNoteBlockStyle {
        guard text.length > 0 else { return .body }
        let clampedLocation = min(max(location, 0), text.length - 1)
        if let raw = text.attribute(.padNoteBlockStyle, at: clampedLocation, effectiveRange: nil) as? String,
           let style = PadNoteBlockStyle(rawValue: raw) {
            return style
        }

        let plain = text.string
        if plain.hasPrefix(PadNoteBlockStyle.bullet.editorPrefix) {
            return .bullet
        }
        if plain.hasPrefix(PadNoteBlockStyle.checklistUnchecked.editorPrefix) {
            return .checklistUnchecked
        }
        if plain.hasPrefix(PadNoteBlockStyle.quote.editorPrefix) {
            return .quote
        }
        return .body
    }

    static func removeEditorPrefix(from text: NSMutableAttributedString) {
        for style in [PadNoteBlockStyle.checklistUnchecked, .bullet, .quote] {
            if text.string.hasPrefix(style.editorPrefix) {
                text.deleteCharacters(in: NSRange(location: 0, length: style.editorPrefixLength))
                return
            }
        }
    }

    static func contentText(for text: NSAttributedString) -> String {
        let mutable = NSMutableAttributedString(attributedString: text)
        removeEditorPrefix(from: mutable)
        return mutable.string
    }

    static func attributes(for style: PadNoteBlockStyle, bold: Bool = false, inlineCode: Bool = false, isPrefix: Bool = false) -> [NSAttributedString.Key: Any] {
        var values: [NSAttributedString.Key: Any] = [
            .font: font(for: style, bold: bold, inlineCode: inlineCode, isPrefix: isPrefix),
            .foregroundColor: foregroundColor(for: style),
            .padNoteBlockStyle: style.rawValue,
            .padNoteBold: bold,
            .padNoteInlineCode: inlineCode
        ]

        if inlineCode && !isPrefix {
            values[.backgroundColor] = inlineCodeBackgroundColor
        }

        return values
    }

    private static func blockStyleAndContent(for line: String) -> (PadNoteBlockStyle, String) {
        if let match = line.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
            return (.heading, String(line[match.upperBound...]))
        }
        if line.hasPrefix("- [ ] ") {
            return (.checklistUnchecked, String(line.dropFirst(6)))
        }
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            return (.checklistUnchecked, String(line.dropFirst(6)))
        }
        if line.hasPrefix("- ") {
            return (.bullet, String(line.dropFirst(2)))
        }
        if line.hasPrefix("* ") {
            return (.bullet, String(line.dropFirst(2)))
        }
        if line.hasPrefix("> ") {
            return (.quote, String(line.dropFirst(2)))
        }
        return (.body, line)
    }

    private static func makeParagraph(content: String, style: PadNoteBlockStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()

        if !style.editorPrefix.isEmpty {
            result.append(NSAttributedString(
                string: style.editorPrefix,
                attributes: attributes(for: style, isPrefix: true)
            ))
        }

        result.append(parseInlineMarkdown(content, style: style))
        if result.length == 0 {
            result.append(NSAttributedString(string: "", attributes: attributes(for: style)))
        }
        return result
    }

    private static func parseInlineMarkdown(_ content: String, style: PadNoteBlockStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var index = content.startIndex

        while index < content.endIndex {
            if content[index...].hasPrefix("**"),
               let closing = content[index...].dropFirst(2).range(of: "**") {
                let start = content.index(index, offsetBy: 2)
                let fragment = String(content[start..<closing.lowerBound])
                result.append(NSAttributedString(
                    string: fragment,
                    attributes: attributes(for: style, bold: true)
                ))
                index = closing.upperBound
                continue
            }

            if content[index] == "`",
               let closing = content[content.index(after: index)...].firstIndex(of: "`") {
                let start = content.index(after: index)
                let fragment = String(content[start..<closing])
                result.append(NSAttributedString(
                    string: fragment,
                    attributes: attributes(for: style, inlineCode: true)
                ))
                index = content.index(after: closing)
                continue
            }

            let nextSpecial = nextSpecialIndex(in: content, from: index)
            let fragment = String(content[index..<nextSpecial])
            result.append(NSAttributedString(
                string: fragment,
                attributes: attributes(for: style)
            ))
            index = nextSpecial
        }

        return result
    }

    private static func nextSpecialIndex(in string: String, from index: String.Index) -> String.Index {
        var cursor = index
        while cursor < string.endIndex {
            if string[cursor...].hasPrefix("**") || string[cursor] == "`" {
                return cursor
            }
            cursor = string.index(after: cursor)
        }
        return string.endIndex
    }

    private static func inlineMarkdown(from text: NSAttributedString) -> String {
        guard text.length > 0 else { return "" }
        var result = ""

        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attrs, range, _ in
            let fragment = escapedMarkdown(text.attributedSubstring(from: range).string)
            let isBold = (attrs[.padNoteBold] as? Bool) == true
            let isCode = (attrs[.padNoteInlineCode] as? Bool) == true

            if isCode {
                result += "`\(fragment)`"
            } else if isBold {
                result += "**\(fragment)**"
            } else {
                result += fragment
            }
        }

        return result
    }

    private static func escapedMarkdown(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "*", with: "\\*")
    }

    private static func foregroundColor(for style: PadNoteBlockStyle) -> Any {
        platformForegroundColor(for: style)
    }

    private static var inlineCodeBackgroundColor: Any {
        platformInlineCodeBackgroundColor
    }

    private static func font(for style: PadNoteBlockStyle, bold: Bool, inlineCode: Bool, isPrefix: Bool) -> Any {
        platformFont(for: style, bold: bold, inlineCode: inlineCode, isPrefix: isPrefix)
    }
}

extension NSAttributedString.Key {
    static let padNoteBlockStyle = NSAttributedString.Key("ufo.pad.noteBlockStyle")
    static let padNoteBold = NSAttributedString.Key("ufo.pad.noteBold")
    static let padNoteInlineCode = NSAttributedString.Key("ufo.pad.noteInlineCode")
}

#endif
