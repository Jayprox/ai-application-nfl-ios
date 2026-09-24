//
//  PropGrading.swift
//  Chalk That NFL
//
//  Pure port of PropsPage.jsx's gradeProp()/LEAN_BADGE/GRADE_VARIANT/
//  leanSortKey() — kept separate from the Views below for the same
//  reason Views/Shared/Badges.swift's OddsBadgeLogic is: the grading/
//  sort math is easy to read and hand-verify without also reasoning
//  about SwiftUI's ViewBuilder rules. Backend hands over raw
//  ingredients (the market line + the player's real final_value once
//  the game is final); this is where "what actually happened against
//  that line" gets described — same division of labor OddsBadge/
//  gradeSpread already use for game-level odds, never a probability or
//  confidence claim.
//
import Foundation

enum PropLean: String {
    case over
    case under
    case tossUp = "toss_up"

    /// Web's LEAN_BADGE — one shared token per lean, "no read" for a
    /// missing/unrecognized value (not enough recent-form sample).
    var badgeLabel: String {
        switch self {
        case .over: return "OVER"
        case .under: return "UNDER"
        case .tossUp: return "TOSS-UP"
        }
    }
}

/// A final game's real outcome against the locked line — never a grade
/// of whether the pregame lean called it correctly, just "what hit,"
/// same framing OddsBadge.jsx's gradeSpread/gradeTotal/gradeMoneyline
/// already use for game odds.
enum PropGrade: Hashable {
    case voidNoBoxScore
    case voidNoLine
    case scored
    case noTd
    case push(line: String)
    case over(line: String, actual: String)
    case under(line: String, actual: String)

    var label: String {
        switch self {
        case .voidNoBoxScore: return "Void — no box score"
        case .voidNoLine: return "Void — no line"
        case .scored: return "Scored a TD"
        case .noTd: return "No TD"
        case .push(let line): return "\(line) (Push)"
        case .over(let line, let actual): return "O \(line) (\(actual))"
        case .under(let line, let actual): return "U \(line) (\(actual))"
        }
    }

    /// Web's GRADE_VARIANT.check — a leading "✓ " on every real
    /// outcome, not on push/void (neither is a real over/under result).
    var showsCheck: Bool {
        switch self {
        case .voidNoBoxScore, .voidNoLine, .push:
            return false
        case .scored, .noTd, .over, .under:
            return true
        }
    }

    /// Web's GRADE_VARIANT color — over/scored positive (green),
    /// under/no_td negative (red), push/void neutral gray. Fixes the
    /// 2026-09-18 "Unders showing green is confusing" bug web itself
    /// once had — this enum makes that distinction impossible to lose
    /// again since over/under are separate cases, not one shared color.
    enum Tone {
        case positive, negative, neutral
    }

    var tone: Tone {
        switch self {
        case .scored, .over:
            return .positive
        case .noTd, .under:
            return .negative
        case .voidNoBoxScore, .voidNoLine, .push:
            return .neutral
        }
    }
}

enum PropGradingLogic {
    /// Formats a NUMERIC(6,1) line value back to its canonical 1-decimal
    /// string (e.g. 74.5 -> "74.5", 288.0 -> "288.0") — matching exactly
    /// what Postgres/pg hands the web frontend as a raw string (web
    /// never re-formats `prop.line` for display, just interpolates it
    /// as-is). Distinct from `formatWholeNumber` below, which is for
    /// values that ARE already real JSON integers server-side.
    static func formatLine(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// Formats a real box-score stat value (final_value) or a games-
    /// played count — these arrive already Number()-coerced to whole
    /// JS integers server-side, so web's template-literal interpolation
    /// never shows a decimal for them either.
    static func formatWholeNumber(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    /// Web's formatPrice() — American odds prices are NUMERIC(7,2)
    /// server-side ("−115.00"/"120.00" as raw strings) but web always
    /// re-derives them with `Number(price)` before display, which drops
    /// the fixed 2-decimal formatting and adds the "+" sign for a
    /// positive price. Real odds prices are always whole numbers in
    /// practice; the fractional fallback is defensive only.
    static func formatPrice(_ price: Double?) -> String {
        guard let price else { return "—" }
        if price == price.rounded() {
            let intValue = Int(price)
            return intValue > 0 ? "+\(intValue)" : "\(intValue)"
        }
        return price > 0 ? "+\(String(format: "%g", price))" : String(format: "%g", price)
    }

    /// Web's gradeProp() — returns nil (pregame LeanBadge stays up)
    /// only when the game isn't final yet. Once final, ALWAYS returns a
    /// real grade (see the 2026-09-18 "TOSS-UP badges never finalize"
    /// fix this mirrors) — a genuine void (no box-score row at all)
    /// renders as its own distinct badge rather than ever falling back
    /// to looking like a still-in-progress game.
    static func grade(_ prop: PropRow) -> PropGrade? {
        guard prop.gameStatus == "final" else { return nil }

        guard let finalValue = prop.finalValue else {
            return .voidNoBoxScore
        }

        if prop.market == "player_anytime_td" {
            return finalValue > 0 ? .scored : .noTd
        }

        guard let line = prop.line else {
            return .voidNoLine
        }

        let lineText = formatLine(line)
        let actualText = formatWholeNumber(finalValue)
        if finalValue == line {
            return .push(line: lineText)
        }
        return finalValue > line ? .over(line: lineText, actual: actualText) : .under(line: lineText, actual: actualText)
    }

    /// Web's leanSortKey() — a real over/under lean before a toss-up
    /// before a no-read, and within the real leans, the strongest
    /// edge_pct first (a plain descriptive ratio, never a confidence
    /// score — see PropModels.swift's own header comment).
    static func sortKey(_ prop: PropRow) -> (tier: Int, negatedEdge: Double) {
        let tier: Int
        switch prop.lean {
        case "over", "under": tier = 0
        case "toss_up": tier = 1
        default: tier = 2
        }
        return (tier, -(prop.edgePct ?? 0))
    }

    static func isBefore(_ a: PropRow, _ b: PropRow) -> Bool {
        let ka = sortKey(a)
        let kb = sortKey(b)
        if ka.tier != kb.tier { return ka.tier < kb.tier }
        return ka.negatedEdge < kb.negatedEdge
    }
}
