//
//  PicksModels.swift
//  Chalk That NFL
//
//  Wire models for backend/routes/picks.js — GET /picks (a picks_log
//  row, joined through players/teams/games for full matchup context)
//  and GET /picks/stats (an agent's hit-rate summary). Both routes are
//  read-only.
//
//  `predicted_line`/`units`/`confidence`/`actual_value` are all
//  NUMERIC columns on picks_log (004_picks_log.sql/006_picks_log_
//  game_lines.sql) and routes/picks.js's SELECT casts none of them —
//  same NUMERIC-as-string situation as odds prices/prop lines, so
//  PickRow needs the same decodeLenientDoubleIfPresent treatment
//  (Extensions/Decoding+Lenient.swift). By contrast, /picks/stats's
//  counts and hit_rate_pct ARE all explicitly Number()-wrapped
//  server-side (see that route's handler), so PicksStats is plain
//  synthesized Decodable.
//
//  `pick_id` is BIGSERIAL (Postgres int8) — node-postgres returns int8
//  as a JSON STRING by default (same reasoning as NUMERIC), and this
//  route never wraps it in Number() either. Modeled as String, not Int
//  — same convention as PortfolioSlateItem.pickId.
//
import Foundation

struct PickRow: Decodable, Identifiable, Hashable {
    var id: String { pickId }

    let pickId: String
    let agentName: String
    /// "player_stat" | "game_line"
    let pickType: String
    let gameId: String
    let playerId: String?
    let playerName: String?
    let statCategory: String?
    /// "over" | "under" | nil — only meaningful for a player_stat pick.
    let predictedDirection: String?
    let predictedLine: Double?
    /// "h2h" | "spreads" | "totals" | nil — only meaningful for a
    /// game_line pick.
    let market: String?
    let predictedTeamId: Int?
    let predictedTeamAbbr: String?
    let units: Double?
    let confidence: Double?
    let reasoning: String?
    /// "pending" | "correct" | "incorrect" | "push" | "void"
    let status: String
    let actualValue: Double?
    let gradedAt: String?
    let createdAt: String?
    let season: Int?
    let week: Int?
    let gameDatetime: String?
    let homeTeamAbbr: String?
    let awayTeamAbbr: String?

    private enum CodingKeys: String, CodingKey {
        case pickId, agentName, pickType, gameId, playerId, playerName
        case statCategory, predictedDirection, predictedLine, market
        case predictedTeamId, predictedTeamAbbr, units, confidence, reasoning
        case status, actualValue, gradedAt, createdAt, season, week
        case gameDatetime, homeTeamAbbr, awayTeamAbbr
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pickId = try container.decode(String.self, forKey: .pickId)
        agentName = try container.decode(String.self, forKey: .agentName)
        pickType = try container.decode(String.self, forKey: .pickType)
        gameId = try container.decode(String.self, forKey: .gameId)
        playerId = try container.decodeIfPresent(String.self, forKey: .playerId)
        playerName = try container.decodeIfPresent(String.self, forKey: .playerName)
        statCategory = try container.decodeIfPresent(String.self, forKey: .statCategory)
        predictedDirection = try container.decodeIfPresent(String.self, forKey: .predictedDirection)
        predictedLine = try container.decodeLenientDoubleIfPresent(forKey: .predictedLine)
        market = try container.decodeIfPresent(String.self, forKey: .market)
        predictedTeamId = try container.decodeIfPresent(Int.self, forKey: .predictedTeamId)
        predictedTeamAbbr = try container.decodeIfPresent(String.self, forKey: .predictedTeamAbbr)
        units = try container.decodeLenientDoubleIfPresent(forKey: .units)
        confidence = try container.decodeLenientDoubleIfPresent(forKey: .confidence)
        reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning)
        status = try container.decode(String.self, forKey: .status)
        actualValue = try container.decodeLenientDoubleIfPresent(forKey: .actualValue)
        gradedAt = try container.decodeIfPresent(String.self, forKey: .gradedAt)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        season = try container.decodeIfPresent(Int.self, forKey: .season)
        week = try container.decodeIfPresent(Int.self, forKey: .week)
        gameDatetime = try container.decodeIfPresent(String.self, forKey: .gameDatetime)
        homeTeamAbbr = try container.decodeIfPresent(String.self, forKey: .homeTeamAbbr)
        awayTeamAbbr = try container.decodeIfPresent(String.self, forKey: .awayTeamAbbr)
    }
}

struct PicksListResponse: Decodable {
    let data: [PickRow]
    let meta: PicksMeta
}

struct PicksMeta: Decodable {
    let count: Int
    let limit: Int
}

/// GET /picks/stats's `{data: {...}}` payload — every field here is
/// server-side Number()-wrapped (see routes/picks.js), so no lenient
/// decoding needed.
struct PicksStats: Decodable {
    let agentName: String?
    let total: Int
    let pending: Int
    let correct: Int
    let incorrect: Int
    let push: Int
    let void: Int
    let decided: Int
    let hitRatePct: Double?
}
