//
//  PortfolioModels.swift
//  Chalk That NFL
//
//  Wire model for backend/lib/portfolio.js's buildSlate() result, as
//  returned by POST /portfolio/slate (backend/routes/portfolio.js) —
//  {data: {season, week, dry_run, unit_size, considered, picked,
//  skipped: [...], slate: [...]}}. Unlike PropRow/RankingRow/EdgeRow,
//  NONE of this response's numeric fields need lenient decoding:
//  `unit_size` is the route's own `Number(unitSizeRaw)`, and every
//  slate item's `model_margin`/`units` are either edge.js's own
//  already-Number()-coerced output or that same plain unitSize value —
//  never a raw NUMERIC-as-string. So this whole file is plain
//  synthesized Decodable, no custom init needed anywhere.
//
//  `pick_id` is the one exception worth flagging even though it needs
//  no special decoding here: picks_log.pick_id is BIGSERIAL (Postgres
//  int8), which node-postgres returns as a JSON STRING by default (same
//  precision-safety reasoning as NUMERIC — see Decoding+Lenient.swift's
//  header) and portfolio.js never wraps it in Number(). Modeled as
//  String?, not Int? — nil on a dry_run preview (buildSlate only
//  attaches pick_id to `slate` entries once they're actually inserted;
//  see that function's final `slate: dryRun ? slate : slate.map(...)`
//  branch).
//
import Foundation

struct PortfolioSlateResult: Decodable {
    let season: Int
    let week: Int
    let dryRun: Bool
    let unitSize: Double
    let considered: Int
    let picked: Int
    let skipped: [PortfolioSkip]
    let slate: [PortfolioSlateItem]
}

struct PortfolioSkip: Decodable, Identifiable, Hashable {
    var id: String { "\(gameId)-\(reason)" }
    let gameId: String
    let reason: String
}

struct PortfolioSlateItem: Decodable, Identifiable, Hashable {
    var id: String { pickId ?? gameId }

    let agentName: String
    /// Always "game_line" — this agent only ever produces the h2h/
    /// spreads-sourced game_line shape (see lib/portfolio.js's own
    /// header comment on why player_stat picks never come from here).
    let pickType: String
    let gameId: String
    /// "h2h" | "spreads" — the edge agent's marketFavorite() never
    /// returns a "totals" source (see edge.js), so this is never that.
    let market: String
    let predictedTeamId: Int
    let units: Double
    let reasoning: String?
    /// nil only when the picked side's model lean itself had no
    /// signal at all — see edge.js's compareGameEdge() weak-basis
    /// branch.
    let modelMargin: Double?
    let modelFavorite: String?
    let marketFavorite: String?
    /// Along for display only ("AWAY @ HOME") — never written to
    /// picks_log itself, see lib/portfolio.js's own comment on these
    /// two fields.
    let homeTeamId: Int
    let awayTeamId: Int
    let pickId: String?
}
