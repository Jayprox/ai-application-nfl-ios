//
//  PlayerInsightModels.swift
//  Chalk That NFL
//
//  Wire models for GET /insights/players/:id (backend/routes/insights.js
//  + lib/insights.js) — the deterministic "matchup / recent form /
//  situational / role trend" label layer that powers the web app's
//  "MATCHUP"-style cards above the stat tabs. Deliberately a SEPARATE
//  endpoint from POST /query (that route's own header comment: "no
//  predictive calculations") — this is the one place in the app where a
//  label/sentence is server-computed rather than a raw stat, and that's
//  by design on the backend, not something to replicate client-side.
//
//  `note` is always a fully server-computed, ready-to-display string
//  whenever `label` isn't null (see lib/insights.js's own note-building
//  per category) — nothing here recomputes or rephrases it.
//
import Foundation

struct PlayerInsightEntry: Decodable, Identifiable {
    var id: String { category }
    let category: String
    /// Nullable label -- insufficient sample, no scheduled next game,
    /// special-teams position, etc (see lib/insights.js's per-category
    /// comments). Exact vocab per category, confirmed against that file:
    ///   matchup:      FAVORABLE_MATCHUP | TOUGH_MATCHUP | NEUTRAL_MATCHUP
    ///   recent_form:  HOT | COLD | NEUTRAL
    ///   situational:  STRONG | WEAK | NEUTRAL
    ///   role_trend:   INCREASING | DECREASING | STEADY
    let label: String?
    let note: String?
}

struct PlayerInsightsData: Decodable {
    let playerId: String
    let season: Int
    let insights: [PlayerInsightEntry]
}

/// Pure display-mapping logic, kept separate from any View so the
/// category-label/tone rules are easy to hand-verify against
/// PlayerInsights.jsx without also reasoning about SwiftUI. Ported
/// line-for-line from that file's CATEGORY_LABEL/POSITIVE_LABELS/
/// NEGATIVE_LABELS/formatLabel — not a re-derivation.
enum PlayerInsightDisplay {
    enum Tone {
        case positive, negative, neutral
    }

    private static let categoryLabels: [String: String] = [
        "matchup": "Matchup",
        "recent_form": "Recent Form",
        "situational": "Situational",
        "role_trend": "Role Trend",
    ]

    /// Only the known positive/negative labels are called out — any
    /// other label (a neutral bucket, or a future enum value this app
    /// doesn't know about yet) falls through to the neutral tone, same
    /// as PlayerInsights.jsx's own badgeStyle() fallback.
    private static let positiveLabels: Set<String> = ["FAVORABLE_MATCHUP", "HOT", "STRONG", "INCREASING"]
    private static let negativeLabels: Set<String> = ["TOUGH_MATCHUP", "COLD", "WEAK", "DECREASING"]

    static func categoryLabel(_ category: String) -> String {
        categoryLabels[category] ?? category
    }

    static func formatLabel(_ label: String) -> String {
        label.replacingOccurrences(of: "_", with: " ")
    }

    static func tone(_ label: String) -> Tone {
        if positiveLabels.contains(label) { return .positive }
        if negativeLabels.contains(label) { return .negative }
        return .neutral
    }
}
