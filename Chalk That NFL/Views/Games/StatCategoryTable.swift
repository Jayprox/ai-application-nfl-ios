//
//  StatCategoryTable.swift
//  Chalk That NFL
//
//  One shared, generic table view reused by both GameBoxScoreSection and
//  GamePlayerStatsSection — mirrors GameDetailPage.jsx's single
//  BoxScoreCategoryTable component, which both the Live Box Score and
//  Player Stats sections already reuse unchanged server-side (see that
//  file's own header comment: "Reuses ALL_BOX_SCORE_CATEGORIES and
//  BoxScoreCategoryTable unchanged from the box score rework"). Renders
//  nothing at all when every row is filtered out (same "don't show a
//  table with nothing in it" norm as web's own `if (filtered.length ===
//  0) return null`).
//
//  Generic over Row rather than three near-duplicate views (one per
//  BoxScoreOffenseRow/DefenseRow/SpecialTeamsRow, doubled again for the
//  season-stats Double? variants) — the column list and per-row value
//  formatting are supplied by the caller as plain closures, so the
//  filtering/layout logic itself only needs writing and hand-verifying
//  once.
//
//  Player names push to PlayerDetailView via a destination-based
//  NavigationLink (not NavigationLink(value:) against a shared route
//  enum) on purpose: GameDetailView itself is reachable from THREE
//  different NavigationStacks with three different route-enum types
//  (Board's own stack and ResearchHomeView both use ResearchRoute;
//  AgentsHomeView uses AgentsRoute) — a value-based link here would only
//  navigate correctly under whichever one of those happens to declare a
//  matching `.navigationDestination(for:)`, silently no-op under the
//  other two. A destination-based link works under any enclosing stack.
//
//  Fixed-width columns + horizontal scroll (2026-09-21, JD-reported bug):
//  the name column originally used `.frame(maxWidth: .infinity)` to
//  fill whatever space the fixed-width stat columns left over. That's
//  fine for a 3-4 column table (Passing, Rushing, ...) but for Defense's
//  8 columns (SOLO/AST/SACK/INT/PD/FF/FR/TD, 40pt each = 320pt) it left
//  almost no room on a phone screen, and SwiftUI's Text — given a frame
//  only a few points wide — wraps character-by-character rather than
//  word-by-word ("Aidan Hutchinson" rendering as one letter per line).
//  Web never hits this because its `<table>` isn't width-constrained —
//  it wraps each table in its own `overflow-x-auto` div and lets the
//  browser auto-size columns to their content, scrolling horizontally
//  when the table is wider than the viewport (confirmed against
//  GameDetailPage.jsx's own BoxScoreCategoryTable markup). Matched here
//  the same way: the name column gets a fixed width generous enough for
//  a real player name on one line, and the whole header+rows block sits
//  in its own ScrollView(.horizontal) — a 3-4 column table still fits
//  the screen and never shows a scrollbar; an 8-column Defense table
//  scrolls sideways instead of crushing the name column.
//
import SwiftUI

struct StatColumn<Row> {
    let key: String
    let label: String
    let value: (Row) -> String
}

struct StatCategoryTable<Row: Identifiable>: View {
    let title: String
    let rows: [Row]
    let isIncluded: (Row) -> Bool
    let columns: [StatColumn<Row>]
    let playerId: (Row) -> String
    let playerName: (Row) -> String
    let playerPosition: (Row) -> String

    private let nameColumnWidth: CGFloat = 132
    private let statColumnWidth: CGFloat = 42

    private var filteredRows: [Row] { rows.filter(isIncluded) }

    var body: some View {
        let filtered = filteredRows
        if !filtered.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.brandBody(11, weight: .medium))
                    .foregroundStyle(Color.inkDim)

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Text("Player")
                                .frame(width: nameColumnWidth, alignment: .leading)
                            ForEach(columns, id: \.key) { column in
                                Text(column.label)
                                    .frame(width: statColumnWidth, alignment: .trailing)
                            }
                        }
                        .font(.brandBody(10, weight: .medium))
                        .foregroundStyle(Color.inkFaint)
                        .padding(.bottom, 3)

                        ForEach(filtered) { row in
                            HStack(spacing: 4) {
                                NavigationLink {
                                    PlayerDetailView(playerId: playerId(row))
                                } label: {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(playerName(row))
                                            .font(.brandBody(12, weight: .medium))
                                            .foregroundStyle(Color.ink)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        Text(playerPosition(row))
                                            .font(.brandBody(10))
                                            .foregroundStyle(Color.inkFaint)
                                    }
                                    .frame(width: nameColumnWidth, alignment: .leading)
                                }

                                ForEach(columns, id: \.key) { column in
                                    Text(column.value(row))
                                        .font(.brandBody(12))
                                        .foregroundStyle(Color.ink)
                                        .frame(width: statColumnWidth, alignment: .trailing)
                                }
                            }
                            .padding(.vertical, 3)
                            .overlay(alignment: .bottom) {
                                Rectangle().frame(height: 1).foregroundStyle(Color.line)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }
}
