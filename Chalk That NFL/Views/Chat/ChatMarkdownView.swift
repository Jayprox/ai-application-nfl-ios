//
//  ChatMarkdownView.swift
//  Chalk That NFL
//
//  Renders ChatMarkdown.parse()'s blocks — mirrors ChatPage.jsx's
//  renderMarkdown()/renderMarkdownBlock(): paragraphs (line breaks
//  preserved within a block), bullet/numbered lists, and simple pipe
//  tables (horizontally scrollable, same as web's own `overflow-x-auto`
//  wrapper), each with **bold** spans resolved inline.
//
import SwiftUI

struct ChatMarkdownView: View {
    let content: String

    var body: some View {
        let blocks = ChatMarkdown.parse(content)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: ChatMarkdownBlock) -> some View {
        switch block {
        case .paragraph(let lines):
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, spans in
                    inlineText(spans)
                }
            }

        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, spans in
                    HStack(alignment: .top, spacing: 6) {
                        Text(ordered ? "\(index + 1)." : "\u{2022}")
                        inlineText(spans)
                    }
                }
            }

        case .table(let header, let rows):
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(Array(header.enumerated()), id: \.offset) { _, spans in
                            inlineText(spans)
                                .fontWeight(.semibold)
                                .padding(8)
                                .frame(minWidth: 72, alignment: .leading)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle().frame(height: 1).foregroundStyle(Color.line)
                    }

                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, spans in
                                inlineText(spans)
                                    .padding(8)
                                    .frame(minWidth: 72, alignment: .leading)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            Rectangle().frame(height: 1).foregroundStyle(Color.line)
                        }
                    }
                }
            }
        }
    }

    private func inlineText(_ spans: [ChatInlineSpan]) -> Text {
        spans.reduce(Text("")) { partial, span in
            switch span {
            case .plain(let value):
                return partial + Text(value)
            case .bold(let value):
                return partial + Text(value).fontWeight(.bold)
            }
        }
    }
}
