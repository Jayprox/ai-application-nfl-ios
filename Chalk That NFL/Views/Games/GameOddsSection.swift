//
//  GameOddsSection.swift
//  Chalk That NFL
//
//  Mirrors GameDetailPage.jsx's "Odds" section — every synced
//  bookmaker/market for this one game, narrowed to the five majors web
//  itself narrows to (BOOKMAKER_DISPLAY/BOOKMAKER_ORDER) even though
//  GET /odds/games/:id returns every book The Odds API has. Genuinely
//  separate logic from Board's DK-only OddsBadge/OddsChip (Views/
//  Shared/Badges.swift) — no shared code between them, same as web's
//  own OddsBadge.jsx vs. this page never sharing formatPoint().
//
import SwiftUI

/// Pure formatting/grouping logic, kept separate from the View — mirrors
/// GameDetailPage.jsx's own top-level constants/formatPoint().
enum GameOddsDisplay {
    static let bookmakerDisplay: [String: String] = [
        "betmgm": "BetMGM",
        "draftkings": "DraftKings",
        "fanduel": "FanDuel",
        "bovada": "Bovada",
        "williamhill_us": "Caesars",
    ]
    static let bookmakerOrder = ["betmgm", "draftkings", "fanduel", "bovada", "williamhill_us"]

    static let marketLabel: [String: String] = [
        "spreads": "Spread",
        "h2h": "Moneyline",
        "totals": "Total",
        "team_totals": "Team Total",
    ]
    static let marketOrder = ["spreads", "h2h", "totals", "team_totals"]

    /// Matches web's formatPoint(): the value run through Number() then
    /// JS's default (trailing-zero-stripped) toString, with an explicit
    /// "+" for a positive value. nil becomes "—".
    static func formatPoint(_ value: Double?) -> String {
        guard let value else { return "\u{2014}" }
        let text = PortfolioFormat.number(value)
        return value > 0 ? "+\(text)" : text
    }

    /// Matches web's raw `r.total_point ?? '—'` — unlike formatPoint
    /// above, GameDetailPage.jsx never runs total_point through
    /// Number(), so it displays the NUMERIC(5,1) column's own string
    /// form verbatim (always exactly one decimal digit). Reuses
    /// PropGradingLogic.formatLine's %.1f convention — the same NUMERIC-
    /// as-string situation as a prop line.
    static func formatRawPoint(_ value: Double?) -> String {
        guard let value else { return "\u{2014}" }
        return PropGradingLogic.formatLine(value)
    }

    /// Filters to the five known books, groups by market, sorts rows by
    /// BOOKMAKER_ORDER and groups by MARKET_ORDER, drops any market with
    /// no synced rows — mirrors web's `oddsByMarket` computation.
    static func grouped(_ bookmakers: [BookmakerLine]) -> [(market: String, rows: [BookmakerLine])] {
        let known = bookmakers.filter { bookmakerOrder.contains($0.bookmaker) }
        return marketOrder.compactMap { market in
            let rows = known
                .filter { $0.market == market }
                .sorted {
                    (bookmakerOrder.firstIndex(of: $0.bookmaker) ?? 0) < (bookmakerOrder.firstIndex(of: $1.bookmaker) ?? 0)
                }
            return rows.isEmpty ? nil : (market, rows)
        }
    }
}

struct GameOddsSection: View {
    let game: Game
    let bookmakers: [BookmakerLine]

    private var groups: [(market: String, rows: [BookmakerLine])] {
        GameOddsDisplay.grouped(bookmakers)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Odds")
                .font(.brandBody(13, weight: .semibold))
                .foregroundStyle(Color.inkFaint)
                .textCase(.uppercase)

            if groups.isEmpty {
                Text("No odds synced yet for this game.")
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(groups, id: \.market) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(GameOddsDisplay.marketLabel[group.market] ?? group.market)
                                .font(.brandBody(11, weight: .medium))
                                .foregroundStyle(Color.inkDim)

                            VStack(spacing: 6) {
                                ForEach(Array(group.rows.enumerated()), id: \.offset) { _, row in
                                    oddsRow(market: group.market, row: row)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func oddsRow(market: String, row: BookmakerLine) -> some View {
        HStack(alignment: .top) {
            Text(GameOddsDisplay.bookmakerDisplay[row.bookmaker] ?? row.bookmaker)
                .font(.brandBody(13))
                .foregroundStyle(Color.ink)
            Spacer(minLength: 8)
            Text(lineText(market: market, row: row))
                .font(.brandBody(12))
                .foregroundStyle(Color.inkDim)
                .multilineTextAlignment(.trailing)
        }
        .padding(10)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func lineText(market: String, row: BookmakerLine) -> String {
        switch market {
        case "spreads":
            return "\(game.awayTeamAbbr) \(GameOddsDisplay.formatPoint(row.awayPoint)) " +
                "(\(GameOddsDisplay.formatPoint(row.awayPrice))) \u{b7} " +
                "\(game.homeTeamAbbr) \(GameOddsDisplay.formatPoint(row.homePoint)) " +
                "(\(GameOddsDisplay.formatPoint(row.homePrice)))"
        case "h2h":
            return "\(game.awayTeamAbbr) \(GameOddsDisplay.formatPoint(row.awayPrice)) \u{b7} " +
                "\(game.homeTeamAbbr) \(GameOddsDisplay.formatPoint(row.homePrice))"
        case "totals":
            return "O/U \(GameOddsDisplay.formatRawPoint(row.totalPoint)) " +
                "(O \(GameOddsDisplay.formatPoint(row.overPrice)) / U \(GameOddsDisplay.formatPoint(row.underPrice)))"
        case "team_totals":
            let side = row.teamSide == "home" ? game.homeTeamAbbr : game.awayTeamAbbr
            return "\(side) O/U \(GameOddsDisplay.formatRawPoint(row.totalPoint)) " +
                "(O \(GameOddsDisplay.formatPoint(row.overPrice)) / U \(GameOddsDisplay.formatPoint(row.underPrice)))"
        default:
            return ""
        }
    }
}
