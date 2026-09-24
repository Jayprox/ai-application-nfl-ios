//
//  ChatMarkdown.swift
//  Chalk That NFL
//
//  Pure port of ChatPage.jsx's hand-rolled markdown renderer — kept
//  separate from ChatMarkdownView so the block/table/list parsing is
//  easy to read and check without also reasoning about SwiftUI's
//  ViewBuilder rules (same "pure logic separate from View" precedent as
//  OddsBadgeLogic/PropGradingLogic).
//
//  Deliberately minimal, same scope web covers — bold spans, bullet/
//  numbered lists, and simple GFM-style pipe tables, not the full
//  markdown spec — because that's genuinely all the model reaches for
//  (see web's own header comment: the exact same edge data has come
//  back as a bulleted list in one reply and a pipe table in another,
//  both correct, just styled differently by the model). This is a
//  best-effort rendering aid, not a data-parity concern the way every
//  other model in this app is — the underlying reply text is identical
//  either way; only how it's visually chunked can differ slightly from
//  web's exact regex behavior on unusual input (e.g. a stray literal
//  "**" with no matching close is rendered literally here rather than
//  reproducing the JS regex's exact edge-case fallback).
//
import Foundation

enum ChatInlineSpan: Hashable {
    case plain(String)
    case bold(String)
}

enum ChatMarkdownBlock: Hashable {
    case paragraph(lines: [[ChatInlineSpan]])
    case list(ordered: Bool, items: [[ChatInlineSpan]])
    case table(header: [[ChatInlineSpan]], rows: [[[ChatInlineSpan]]])
}

enum ChatMarkdown {
    /// Splits on blank lines (mirrors web's `content.split(/\n\s*\n/)`),
    /// then classifies each resulting block as a table, a list, or a
    /// plain paragraph — mirrors web's renderMarkdownBlock().
    static func parse(_ content: String) -> [ChatMarkdownBlock] {
        var blocks: [[String]] = []
        var current: [String] = []
        for rawLine in content.components(separatedBy: "\n") {
            if rawLine.trimmingCharacters(in: .whitespaces).isEmpty {
                if !current.isEmpty {
                    blocks.append(current)
                    current = []
                }
            } else {
                current.append(rawLine)
            }
        }
        if !current.isEmpty { blocks.append(current) }
        return blocks.compactMap(parseBlock)
    }

    private static func parseBlock(_ lines: [String]) -> ChatMarkdownBlock? {
        guard !lines.isEmpty else { return nil }

        // A header row containing "|" followed by a "---|---"-style
        // separator row = a pipe table.
        if lines.count >= 2, lines[0].contains("|"), isTableSeparatorLine(lines[1]) {
            let header = parseTableRow(lines[0]).map(parseInline)
            let rows = lines.dropFirst(2).map { parseTableRow($0).map(parseInline) }
            return .table(header: header, rows: Array(rows))
        }

        // Every line is a bullet ("-"/"*") or numbered ("1.") item = a list.
        let bulletContents = lines.map(bulletContent)
        if bulletContents.allSatisfy({ $0 != nil }) {
            let ordered = isNumberedLine(lines[0])
            return .list(ordered: ordered, items: bulletContents.map { parseInline($0!) })
        }

        return .paragraph(lines: lines.map(parseInline))
    }

    private static func isTableSeparatorLine(_ line: String) -> Bool {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        let cells = trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            var c = cell
            if c.hasPrefix(":") { c.removeFirst() }
            if c.hasSuffix(":") { c.removeLast() }
            return c.count >= 2 && c.allSatisfy { $0 == "-" }
        }
    }

    private static func parseTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// nil unless `line` matches `^\s*[-*]\s+(.*)$` or `^\s*\d+\.\s+(.*)$`
    /// — returns the content after the marker when it does.
    private static func bulletContent(_ line: String) -> String? {
        let noLeadingSpace = line.drop { $0 == " " || $0 == "\t" }
        if let first = noLeadingSpace.first, first == "-" || first == "*" {
            return requireLeadingWhitespace(noLeadingSpace.dropFirst())
        }
        var index = noLeadingSpace.startIndex
        var sawDigit = false
        while index < noLeadingSpace.endIndex, noLeadingSpace[index].isNumber {
            sawDigit = true
            index = noLeadingSpace.index(after: index)
        }
        guard sawDigit, index < noLeadingSpace.endIndex, noLeadingSpace[index] == "." else { return nil }
        return requireLeadingWhitespace(noLeadingSpace[noLeadingSpace.index(after: index)...])
    }

    private static func isNumberedLine(_ line: String) -> Bool {
        let noLeadingSpace = line.drop { $0 == " " || $0 == "\t" }
        return noLeadingSpace.first?.isNumber == true
    }

    private static func requireLeadingWhitespace(_ s: Substring) -> String? {
        guard let first = s.first, first == " " || first == "\t" else { return nil }
        return String(s.drop { $0 == " " || $0 == "\t" })
    }

    /// Splits on `**bold**` spans — mirrors web's
    /// `text.split(/(\*\*[^*]+\*\*)/g)`.
    private static func parseInline(_ text: String) -> [ChatInlineSpan] {
        var spans: [ChatInlineSpan] = []
        var remaining = Substring(text)
        while let openRange = remaining.range(of: "**") {
            let before = remaining[remaining.startIndex..<openRange.lowerBound]
            let afterOpen = remaining[openRange.upperBound...]
            if let closeRange = afterOpen.range(of: "**"), closeRange.lowerBound > afterOpen.startIndex {
                if !before.isEmpty { spans.append(.plain(String(before))) }
                spans.append(.bold(String(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])))
                remaining = afterOpen[closeRange.upperBound...]
            } else {
                // No matching close (or an empty "****") — treat this
                // "**" as literal text and keep scanning past it.
                if !before.isEmpty { spans.append(.plain(String(before))) }
                spans.append(.plain("**"))
                remaining = afterOpen
            }
        }
        if !remaining.isEmpty { spans.append(.plain(String(remaining))) }
        return spans
    }
}
