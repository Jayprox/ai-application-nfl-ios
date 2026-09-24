//
//  Badges.swift
//  Chalk That NFL
//
//  Native equivalents of web's StatusBadge.jsx / WeatherBadge.jsx /
//  InjuryBadge.jsx — same label text, same severity color mapping, so a
//  status reads identically on both clients. Each renders EmptyView for
//  data that shouldn't show a badge at all (matches web's "graceful,
//  not just non-broken" empty-state convention — see InjuryBadge.jsx's
//  own comment).
//
import SwiftUI

/// Mirrors StatusBadge.jsx.
struct GameStatusBadge: View {
    let status: String
    var period: Int?
    var clock: String?

    private var hasClock: Bool { status == "in_progress" && period != nil && clock?.isEmpty == false }

    private var label: String {
        if hasClock, let period, let clock { return "Q\(period) \(clock)" }
        switch status {
        case "scheduled": return "Scheduled"
        case "in_progress": return "Live"
        case "final": return "Final"
        case "postponed": return "Postponed"
        default: return status.capitalized
        }
    }

    private var foreground: Color {
        switch status {
        case "in_progress": return .onAccent
        case "postponed": return .caution
        default: return status == "final" ? .ink : .inkDim
        }
    }

    private var background: Color {
        switch status {
        case "in_progress": return .accent
        case "postponed": return .caution.opacity(0.12)
        default: return .surface2
        }
    }

    var body: some View {
        Text(label)
            .font(.brandBody(12, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

/// Mirrors WeatherBadge.jsx, including the 8-point compass bucketing.
struct WeatherBadge: View {
    let condition: String?
    var tempF: Double?
    var windMph: Double?
    var windDirectionDeg: Double?

    private static let compassPoints = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

    private func compass(for deg: Double) -> String {
        let normalized = (deg.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let index = Int((normalized / 45).rounded()) % 8
        return Self.compassPoints[index]
    }

    private var label: String? {
        guard let condition else { return nil }
        if condition == "dome" { return "Dome" }

        var parts: [String] = []
        switch condition {
        case "sunny": parts.append("Sunny")
        case "overcast": parts.append("Overcast")
        case "rain": parts.append("Rain")
        case "snow": parts.append("Snow")
        default: break
        }
        if let windMph {
            let compassPart = windDirectionDeg.map { "\(compass(for: $0)) " } ?? ""
            parts.append("Winds \(compassPart)\(Int(windMph.rounded())) mph")
        }
        if let tempF { parts.append("\(Int(tempF.rounded()))°F") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        if let label {
            Text(label)
                .font(.brandBody(12, weight: .medium))
                .foregroundStyle(Color.inkDim)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
}

/// Mirrors InjuryBadge.jsx's severity ladder (caution -> accent -> negative).
struct InjuryStatusBadge: View {
    let reportStatus: String?
    var primaryInjury: String?
    var secondaryInjury: String?

    private var label: String? {
        switch reportStatus {
        case "questionable": return "Questionable"
        case "doubtful": return "Doubtful"
        case "out": return "Out"
        case "injured_reserve": return "Injured Reserve"
        case "probable": return "Probable"
        default: return nil
        }
    }

    private var foreground: Color {
        switch reportStatus {
        case "questionable": return .caution
        case "doubtful": return .accent
        case "out", "injured_reserve": return .negative
        case "probable": return .positive
        default: return .inkDim
        }
    }

    private var background: Color {
        switch reportStatus {
        case "questionable": return .caution.opacity(0.12)
        case "doubtful": return .accent.opacity(0.12)
        case "out": return .negative.opacity(0.12)
        case "injured_reserve": return .negative.opacity(0.2)
        case "probable": return .positive.opacity(0.12)
        default: return .surface2
        }
    }

    private var detail: String? {
        let parts = [primaryInjury, secondaryInjury].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    var body: some View {
        if let label, reportStatus != "active" {
            Text("Injury: \(label)" + (detail.map { " – \($0)" } ?? ""))
                .font(.brandBody(12, weight: .medium))
                .foregroundStyle(foreground)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
}

/// Mirrors EdgeBadge.jsx's 3-state "model vs market" pill — shared by
/// Board's Top Edges list and (later) the full Edge page and the Games
/// grid's game cards.
struct EdgeBadge: View {
    /// true = model/market disagree ("worth a closer look"), false =
    /// they agree, nil = not enough signal either way.
    let edge: Bool?

    private var label: String {
        switch edge {
        case .some(true): return "Disagreement"
        case .some(false): return "Agrees"
        case .none: return "No signal"
        }
    }

    private var foreground: Color {
        switch edge {
        case .some(true): return .accent
        case .some(false): return .positive
        case .none: return .inkDim
        }
    }

    private var background: Color {
        switch edge {
        case .some(true): return .accent.opacity(0.12)
        case .some(false): return .positive.opacity(0.12)
        case .none: return .surface2
        }
    }

    var body: some View {
        Text(label)
            .font(.brandBody(12, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

/// One rendered odds chip — either the single combined pregame badge, or
/// one of up to three post-final "what hit" chips. See OddsBadgeLogic
/// below for how these are produced.
struct OddsChip: Identifiable {
    let id: String
    let displayText: String
    /// true = this outcome hit (rendered in the positive color); nil =
    /// a push/tie or the pregame combined badge (neutral color). Never
    /// false — mirrors web's OddsBadge.jsx, which only ever marks a
    /// grade as hit or leaves it unmarked, never "missed" (nothing to
    /// gray out differently than a push).
    let hit: Bool?
}

/// Pure port of OddsBadge.jsx's grading logic — kept separate from the
/// View below so the DraftKings-filtering/grading math is easy to read
/// and check without also reasoning about SwiftUI's ViewBuilder rules.
enum OddsBadgeLogic {
    private static let draftKingsKey = "draftkings"

    /// web's latestDkByMarket() reduces to the single latest-synced row
    /// for a given bookmaker+market. In practice backend/routes/odds.js
    /// already dedups to at most one row per (game_id, bookmaker,
    /// market, team_side) via its own DISTINCT ON query, so this is a
    /// defensive no-op most of the time — kept anyway to match web
    /// exactly rather than assume the server contract never changes.
    private static func latestDK(_ bookmakers: [BookmakerLine], market: String) -> BookmakerLine? {
        let rows = bookmakers.filter { $0.bookmaker == draftKingsKey && $0.market == market }
        guard !rows.isEmpty else { return nil }
        if rows.count == 1 { return rows[0] }
        return rows.max { a, b in
            let da = BackendDate.parse(a.syncedAt) ?? .distantPast
            let db = BackendDate.parse(b.syncedAt) ?? .distantPast
            return da < db
        }
    }

    /// Matches JS's default Number-to-string: whole numbers with no
    /// trailing ".0" (odds/points are always clean decimals from the
    /// vendor — X or X.5 — so this never needs real rounding logic).
    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return String(value)
    }

    private static func formatSigned(_ value: Double) -> String {
        let text = formatNumber(value)
        return value > 0 ? "+\(text)" : text
    }

    private static func gradeSpread(_ spread: BookmakerLine?, margin: Double, homeAbbr: String, awayAbbr: String) -> OddsChip? {
        guard let homePoint = spread?.homePoint else { return nil }
        let awayPoint = spread?.awayPoint ?? -homePoint
        let diff = margin + homePoint
        if diff == 0 {
            return OddsChip(id: "spread", displayText: "DK \(homeAbbr) \(formatSigned(homePoint)) (Push)", hit: nil)
        } else if diff > 0 {
            return OddsChip(id: "spread", displayText: "DK ✓ \(homeAbbr) \(formatSigned(homePoint))", hit: true)
        } else {
            return OddsChip(id: "spread", displayText: "DK ✓ \(awayAbbr) \(formatSigned(awayPoint))", hit: true)
        }
    }

    private static func gradeTotal(_ totals: BookmakerLine?, homeScore: Int, awayScore: Int) -> OddsChip? {
        guard let totalPoint = totals?.totalPoint else { return nil }
        let actual = Double(homeScore + awayScore)
        if actual == totalPoint {
            return OddsChip(id: "total", displayText: "DK O/U \(formatNumber(totalPoint)) (Push)", hit: nil)
        }
        let label = actual > totalPoint
            ? "O \(formatNumber(totalPoint)) (\(Int(actual)))"
            : "U \(formatNumber(totalPoint)) (\(Int(actual)))"
        return OddsChip(id: "total", displayText: "DK ✓ \(label)", hit: true)
    }

    private static func gradeMoneyline(_ moneyline: BookmakerLine?, margin: Double, homeAbbr: String, awayAbbr: String) -> OddsChip? {
        guard let homePrice = moneyline?.homePrice, let awayPrice = moneyline?.awayPrice else { return nil }
        if margin == 0 {
            return OddsChip(id: "ml", displayText: "DK ML Tie", hit: nil)
        }
        let homeWon = margin > 0
        let winnerAbbr = homeWon ? homeAbbr : awayAbbr
        let winnerPrice = homeWon ? homePrice : awayPrice
        return OddsChip(id: "ml", displayText: "DK ✓ ML \(winnerAbbr) \(formatSigned(winnerPrice))", hit: true)
    }

    /// Returns either zero chips (nothing synced / nothing to show),
    /// one combined pregame chip, or up to three post-final "what hit"
    /// chips — mirrors OddsBadge.jsx's two render modes exactly.
    static func chips(odds: GameOdds?, homeAbbr: String, awayAbbr: String, status: String, homeScore: Int?, awayScore: Int?) -> [OddsChip] {
        guard let bookmakers = odds?.bookmakers, !bookmakers.isEmpty else { return [] }

        let spread = latestDK(bookmakers, market: "spreads")
        let totals = latestDK(bookmakers, market: "totals")
        let moneyline = latestDK(bookmakers, market: "h2h")

        let isGraded = status == "final" && homeScore != nil && awayScore != nil

        if !isGraded {
            var parts: [String] = []
            if let homePoint = spread?.homePoint { parts.append("\(homeAbbr) \(formatSigned(homePoint))") }
            if let totalPoint = totals?.totalPoint { parts.append("O/U \(formatNumber(totalPoint))") }
            if let awayPrice = moneyline?.awayPrice, let homePrice = moneyline?.homePrice {
                parts.append("ML \(formatSigned(awayPrice))/\(formatSigned(homePrice))")
            }
            guard !parts.isEmpty else { return [] }
            return [OddsChip(id: "pregame", displayText: "DK \(parts.joined(separator: " · "))", hit: nil)]
        }

        let margin = Double(homeScore! - awayScore!)
        return [
            gradeSpread(spread, margin: margin, homeAbbr: homeAbbr, awayAbbr: awayAbbr),
            gradeTotal(totals, homeScore: homeScore!, awayScore: awayScore!),
            gradeMoneyline(moneyline, margin: margin, homeAbbr: homeAbbr, awayAbbr: awayAbbr),
        ].compactMap { $0 }
    }
}

/// Renders OddsBadgeLogic's chips as pills — zero, one, or up to three
/// siblings depending on the game/odds state. Renders nothing at all
/// until DraftKings has posted a line for this game, same graceful-
/// empty convention as WeatherBadge/GameStatusBadge above.
struct OddsBadge: View {
    let odds: GameOdds?
    let homeAbbr: String
    let awayAbbr: String
    let status: String
    let homeScore: Int?
    let awayScore: Int?

    var body: some View {
        let chips = OddsBadgeLogic.chips(
            odds: odds,
            homeAbbr: homeAbbr,
            awayAbbr: awayAbbr,
            status: status,
            homeScore: homeScore,
            awayScore: awayScore
        )
        ForEach(chips) { chip in
            Text(chip.displayText)
                .font(.brandBody(12, weight: .medium))
                .foregroundStyle(chip.hit == true ? Color.positive : Color.inkDim)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(chip.hit == true ? Color.positive.opacity(0.12) : Color.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
}
