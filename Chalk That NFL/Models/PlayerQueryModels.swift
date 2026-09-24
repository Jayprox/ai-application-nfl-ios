//
//  PlayerQueryModels.swift
//  Chalk That NFL
//
//  Wire models for POST /query (backend/routes/query.js + lib/stats-
//  query.js) — the shared stats engine PlayerDetailView's stat tabs use
//  (2026-09-22, "match the web version" full-parity phase). Confirmed
//  directly against lib/stats-query.js's PLAYER_STAT_COLUMNS/
//  PLAYER_STAT_TABLES rather than assumed from the route's own docstring.
//
//  Two genuinely different response shapes share this one endpoint,
//  keyed by scope:
//    - season / season_total / last5 / career -> `data` is ONE flat
//      object of stat columns for this player (no player_id/name in it
//      -- the caller already knows who they asked about). Every column
//      is explicitly cast `::float8` server-side (see AVG(...)::float8
//      / SUM(...)::float8 in stats-query.js), so these always decode as
//      real JSON numbers -- no lenient/NUMERIC-as-string handling
//      needed anywhere in this half of the file.
//    - game_log -> `data` is an ARRAY of raw per-game rows (SELECT
//      stats.* with no cast). Column types here come straight from
//      db/schema.sql, same as BoxScoreModels.swift's own game rows:
//      every column is a plain INT except player_defense_game_stats.
//      sacks (NUMERIC(3,1)) and player_special_teams_game_stats.
//      punt_avg (NUMERIC(4,1)), which need decodeLenientDoubleIfPresent.
//
//  One struct per (position_group x shape) pair -- 3 aggregate structs,
//  3 game-log-row structs -- rather than a dynamic [String: Double]
//  decode. A fully-dynamic dictionary decode would be less code, but
//  this app's one hard rule is never showing invented/wrong data, and
//  there's no way to compile-check Swift in this environment -- a
//  silently-wrong dynamic key-casing bug (whether .convertFromSnakeCase
//  reliably applies to a Dictionary's synthesized keys the same way it
//  does to a struct's static CodingKeys isn't something I can verify
//  with certainty here) would fail exactly the way that rule forbids,
//  with no build error to catch it. Explicit flat structs are the same
//  proven pattern already used by every other model in this app
//  (PlayerSeasonStatsModels.swift, BoxScoreModels.swift, etc).
//
//  Column key/label lists mirror frontend/src/constants/statColumns.js's
//  STAT_COLUMNS_BY_POSITION_GROUP exactly (verified line-for-line against
//  that file) -- PlayerStatColumns below is this app's one copy of that
//  table, used both to build StatGrid's entry list and GameLogTable's
//  column headers, so the two can never drift apart from each other the
//  way statColumns.js's own header comment keeps them from drifting from
//  the backend.
//
import Foundation

// MARK: - Request body

struct PlayerQuerySplitsBody: Encodable {
    var homeAway: String?
    var gameSlot: String?
    var weatherCondition: String?
}

struct PlayerQueryRequestBody: Encodable {
    let entityType: String
    let entityId: String
    let scope: String
    /// Omitted entirely for `career` (ignored server-side even if sent,
    /// but PlayerDetailPage.jsx's own queryBody leaves it off for that
    /// scope too -- matched here for an identical request shape).
    var season: Int?
    var splits: PlayerQuerySplitsBody?
}

// MARK: - Response envelope

struct PlayerQueryFreshness: Decodable {
    let syncedAt: String?
}

struct PlayerQueryMeta: Decodable {
    let sampleSize: Int
    let freshness: PlayerQueryFreshness?
}

/// season / season_total / last5 / career -- `data` is always exactly
/// one row (COUNT(*) with no GROUP BY always returns a row, even at
/// sample_size 0 -- see stats-query.js's stripSampleSize(rows[0])), so
/// this is never optional, same "data is never null here" reasoning as
/// PlayerSeasonStatsResponse.
struct PlayerQueryAggregateResponse<Row: Decodable>: Decodable {
    let data: Row
    let meta: PlayerQueryMeta
}

/// game_log -- `data` is an array, empty (not null) when sample_size is 0.
struct PlayerQueryGameLogResponse<Row: Decodable>: Decodable {
    let data: [Row]
    let meta: PlayerQueryMeta
}

// MARK: - Aggregate rows (season / season_total / last5 / career)

struct PlayerQueryOffenseAggregate: Decodable {
    let passAttempts: Double?
    let passCompletions: Double?
    let passingYards: Double?
    let passingTds: Double?
    let interceptionsThrown: Double?
    let sacksTaken: Double?
    let rushAttempts: Double?
    let rushingYards: Double?
    let rushingTds: Double?
    let fumbles: Double?
    let targets: Double?
    let receptions: Double?
    let receivingYards: Double?
    let receivingTds: Double?

    func value(forKey key: String) -> Double? {
        switch key {
        case "pass_attempts": return passAttempts
        case "pass_completions": return passCompletions
        case "passing_yards": return passingYards
        case "passing_tds": return passingTds
        case "interceptions_thrown": return interceptionsThrown
        case "sacks_taken": return sacksTaken
        case "rush_attempts": return rushAttempts
        case "rushing_yards": return rushingYards
        case "rushing_tds": return rushingTds
        case "fumbles": return fumbles
        case "targets": return targets
        case "receptions": return receptions
        case "receiving_yards": return receivingYards
        case "receiving_tds": return receivingTds
        default: return nil
        }
    }
}

struct PlayerQueryDefenseAggregate: Decodable {
    let tacklesSolo: Double?
    let tacklesAssist: Double?
    let sacks: Double?
    let tacklesForLoss: Double?
    let qbHits: Double?
    let interceptions: Double?
    let passesDefended: Double?
    let forcedFumbles: Double?
    let fumbleRecoveries: Double?
    let defensiveTds: Double?

    func value(forKey key: String) -> Double? {
        switch key {
        case "tackles_solo": return tacklesSolo
        case "tackles_assist": return tacklesAssist
        case "sacks": return sacks
        case "tackles_for_loss": return tacklesForLoss
        case "qb_hits": return qbHits
        case "interceptions": return interceptions
        case "passes_defended": return passesDefended
        case "forced_fumbles": return forcedFumbles
        case "fumble_recoveries": return fumbleRecoveries
        case "defensive_tds": return defensiveTds
        default: return nil
        }
    }
}

struct PlayerQuerySpecialTeamsAggregate: Decodable {
    let fgAttempts: Double?
    let fgMade: Double?
    let longestFg: Double?
    let xpAttempts: Double?
    let xpMade: Double?
    let punts: Double?
    let puntYards: Double?
    let puntAvg: Double?
    let kickReturnYards: Double?
    let puntReturnYards: Double?
    let returnTds: Double?

    func value(forKey key: String) -> Double? {
        switch key {
        case "fg_attempts": return fgAttempts
        case "fg_made": return fgMade
        case "longest_fg": return longestFg
        case "xp_attempts": return xpAttempts
        case "xp_made": return xpMade
        case "punts": return punts
        case "punt_yards": return puntYards
        case "punt_avg": return puntAvg
        case "kick_return_yards": return kickReturnYards
        case "punt_return_yards": return puntReturnYards
        case "return_tds": return returnTds
        default: return nil
        }
    }
}

// MARK: - Game log rows (raw, uncast -- see header re: lenient decoding)

/// Fields every game_log row carries regardless of position group (from
/// stats-query.js's shared SELECT prefix: g.game_id, g.week,
/// g.game_datetime, is_home) plus a per-row raw-value lookup so
/// GameLogTable can render any position group's columns generically.
protocol PlayerQueryGameRow {
    var gameId: String { get }
    var week: Int { get }
    var gameDatetime: String? { get }
    var isHome: Bool { get }
    func rawDisplayValue(forKey key: String) -> String
}

struct PlayerQueryOffenseGameRow: Decodable, Identifiable, PlayerQueryGameRow {
    var id: String { gameId }
    let gameId: String
    let season: Int
    let week: Int
    let gameDatetime: String?
    let gameSlot: String?
    let weatherCondition: String?
    let isHome: Bool
    let passAttempts: Int?
    let passCompletions: Int?
    let passingYards: Int?
    let passingTds: Int?
    let interceptionsThrown: Int?
    let sacksTaken: Int?
    let rushAttempts: Int?
    let rushingYards: Int?
    let rushingTds: Int?
    let fumbles: Int?
    let targets: Int?
    let receptions: Int?
    let receivingYards: Int?
    let receivingTds: Int?

    func rawDisplayValue(forKey key: String) -> String {
        switch key {
        case "pass_attempts": return PlayerQueryDisplay.rawInt(passAttempts)
        case "pass_completions": return PlayerQueryDisplay.rawInt(passCompletions)
        case "passing_yards": return PlayerQueryDisplay.rawInt(passingYards)
        case "passing_tds": return PlayerQueryDisplay.rawInt(passingTds)
        case "interceptions_thrown": return PlayerQueryDisplay.rawInt(interceptionsThrown)
        case "sacks_taken": return PlayerQueryDisplay.rawInt(sacksTaken)
        case "rush_attempts": return PlayerQueryDisplay.rawInt(rushAttempts)
        case "rushing_yards": return PlayerQueryDisplay.rawInt(rushingYards)
        case "rushing_tds": return PlayerQueryDisplay.rawInt(rushingTds)
        case "fumbles": return PlayerQueryDisplay.rawInt(fumbles)
        case "targets": return PlayerQueryDisplay.rawInt(targets)
        case "receptions": return PlayerQueryDisplay.rawInt(receptions)
        case "receiving_yards": return PlayerQueryDisplay.rawInt(receivingYards)
        case "receiving_tds": return PlayerQueryDisplay.rawInt(receivingTds)
        default: return "—"
        }
    }
}

struct PlayerQueryDefenseGameRow: Decodable, Identifiable, PlayerQueryGameRow {
    var id: String { gameId }
    let gameId: String
    let season: Int
    let week: Int
    let gameDatetime: String?
    let gameSlot: String?
    let weatherCondition: String?
    let isHome: Bool
    let tacklesSolo: Int?
    let tacklesAssist: Int?
    /// NUMERIC(3,1), no cast in this scope -- lenient decoding (same
    /// column, same reasoning, as BoxScoreDefenseRow.sacks).
    let sacks: Double?
    let tacklesForLoss: Int?
    let qbHits: Int?
    let interceptions: Int?
    let passesDefended: Int?
    let forcedFumbles: Int?
    let fumbleRecoveries: Int?
    let defensiveTds: Int?

    private enum CodingKeys: String, CodingKey {
        case gameId, season, week, gameDatetime, gameSlot, weatherCondition, isHome
        case tacklesSolo, tacklesAssist, sacks, tacklesForLoss, qbHits
        case interceptions, passesDefended, forcedFumbles, fumbleRecoveries, defensiveTds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameId = try container.decode(String.self, forKey: .gameId)
        season = try container.decode(Int.self, forKey: .season)
        week = try container.decode(Int.self, forKey: .week)
        gameDatetime = try container.decodeIfPresent(String.self, forKey: .gameDatetime)
        gameSlot = try container.decodeIfPresent(String.self, forKey: .gameSlot)
        weatherCondition = try container.decodeIfPresent(String.self, forKey: .weatherCondition)
        isHome = try container.decode(Bool.self, forKey: .isHome)
        tacklesSolo = try container.decodeIfPresent(Int.self, forKey: .tacklesSolo)
        tacklesAssist = try container.decodeIfPresent(Int.self, forKey: .tacklesAssist)
        sacks = try container.decodeLenientDoubleIfPresent(forKey: .sacks)
        tacklesForLoss = try container.decodeIfPresent(Int.self, forKey: .tacklesForLoss)
        qbHits = try container.decodeIfPresent(Int.self, forKey: .qbHits)
        interceptions = try container.decodeIfPresent(Int.self, forKey: .interceptions)
        passesDefended = try container.decodeIfPresent(Int.self, forKey: .passesDefended)
        forcedFumbles = try container.decodeIfPresent(Int.self, forKey: .forcedFumbles)
        fumbleRecoveries = try container.decodeIfPresent(Int.self, forKey: .fumbleRecoveries)
        defensiveTds = try container.decodeIfPresent(Int.self, forKey: .defensiveTds)
    }

    func rawDisplayValue(forKey key: String) -> String {
        switch key {
        case "tackles_solo": return PlayerQueryDisplay.rawInt(tacklesSolo)
        case "tackles_assist": return PlayerQueryDisplay.rawInt(tacklesAssist)
        case "sacks": return PlayerQueryDisplay.rawLenientDouble(sacks)
        case "tackles_for_loss": return PlayerQueryDisplay.rawInt(tacklesForLoss)
        case "qb_hits": return PlayerQueryDisplay.rawInt(qbHits)
        case "interceptions": return PlayerQueryDisplay.rawInt(interceptions)
        case "passes_defended": return PlayerQueryDisplay.rawInt(passesDefended)
        case "forced_fumbles": return PlayerQueryDisplay.rawInt(forcedFumbles)
        case "fumble_recoveries": return PlayerQueryDisplay.rawInt(fumbleRecoveries)
        case "defensive_tds": return PlayerQueryDisplay.rawInt(defensiveTds)
        default: return "—"
        }
    }
}

struct PlayerQuerySpecialTeamsGameRow: Decodable, Identifiable, PlayerQueryGameRow {
    var id: String { gameId }
    let gameId: String
    let season: Int
    let week: Int
    let gameDatetime: String?
    let gameSlot: String?
    let weatherCondition: String?
    let isHome: Bool
    let fgAttempts: Int?
    let fgMade: Int?
    let longestFg: Int?
    let xpAttempts: Int?
    let xpMade: Int?
    let punts: Int?
    let puntYards: Int?
    /// NUMERIC(4,1), no cast in this scope -- lenient decoding (same
    /// column, same reasoning, as BoxScoreSpecialTeamsRow.puntAvg).
    let puntAvg: Double?
    let kickReturnYards: Int?
    let puntReturnYards: Int?
    let returnTds: Int?

    private enum CodingKeys: String, CodingKey {
        case gameId, season, week, gameDatetime, gameSlot, weatherCondition, isHome
        case fgAttempts, fgMade, longestFg, xpAttempts, xpMade
        case punts, puntYards, puntAvg, kickReturnYards, puntReturnYards, returnTds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameId = try container.decode(String.self, forKey: .gameId)
        season = try container.decode(Int.self, forKey: .season)
        week = try container.decode(Int.self, forKey: .week)
        gameDatetime = try container.decodeIfPresent(String.self, forKey: .gameDatetime)
        gameSlot = try container.decodeIfPresent(String.self, forKey: .gameSlot)
        weatherCondition = try container.decodeIfPresent(String.self, forKey: .weatherCondition)
        isHome = try container.decode(Bool.self, forKey: .isHome)
        fgAttempts = try container.decodeIfPresent(Int.self, forKey: .fgAttempts)
        fgMade = try container.decodeIfPresent(Int.self, forKey: .fgMade)
        longestFg = try container.decodeIfPresent(Int.self, forKey: .longestFg)
        xpAttempts = try container.decodeIfPresent(Int.self, forKey: .xpAttempts)
        xpMade = try container.decodeIfPresent(Int.self, forKey: .xpMade)
        punts = try container.decodeIfPresent(Int.self, forKey: .punts)
        puntYards = try container.decodeIfPresent(Int.self, forKey: .puntYards)
        puntAvg = try container.decodeLenientDoubleIfPresent(forKey: .puntAvg)
        kickReturnYards = try container.decodeIfPresent(Int.self, forKey: .kickReturnYards)
        puntReturnYards = try container.decodeIfPresent(Int.self, forKey: .puntReturnYards)
        returnTds = try container.decodeIfPresent(Int.self, forKey: .returnTds)
    }

    func rawDisplayValue(forKey key: String) -> String {
        switch key {
        case "fg_attempts": return PlayerQueryDisplay.rawInt(fgAttempts)
        case "fg_made": return PlayerQueryDisplay.rawInt(fgMade)
        case "longest_fg": return PlayerQueryDisplay.rawInt(longestFg)
        case "xp_attempts": return PlayerQueryDisplay.rawInt(xpAttempts)
        case "xp_made": return PlayerQueryDisplay.rawInt(xpMade)
        case "punts": return PlayerQueryDisplay.rawInt(punts)
        case "punt_yards": return PlayerQueryDisplay.rawInt(puntYards)
        case "punt_avg": return PlayerQueryDisplay.rawLenientDouble(puntAvg)
        case "kick_return_yards": return PlayerQueryDisplay.rawInt(kickReturnYards)
        case "punt_return_yards": return PlayerQueryDisplay.rawInt(puntReturnYards)
        case "return_tds": return PlayerQueryDisplay.rawInt(returnTds)
        default: return "—"
        }
    }
}

// MARK: - Column definitions (mirrors statColumns.js)

struct PlayerStatColumnDef: Identifiable {
    let id: String
    let label: String
}

enum PlayerStatColumns {
    static let offense: [PlayerStatColumnDef] = [
        .init(id: "pass_attempts", label: "Pass Attempts"),
        .init(id: "pass_completions", label: "Completions"),
        .init(id: "passing_yards", label: "Passing Yards"),
        .init(id: "passing_tds", label: "Passing TDs"),
        .init(id: "interceptions_thrown", label: "Interceptions"),
        .init(id: "sacks_taken", label: "Sacks Taken"),
        .init(id: "rush_attempts", label: "Rush Attempts"),
        .init(id: "rushing_yards", label: "Rushing Yards"),
        .init(id: "rushing_tds", label: "Rushing TDs"),
        .init(id: "fumbles", label: "Fumbles"),
        .init(id: "targets", label: "Targets"),
        .init(id: "receptions", label: "Receptions"),
        .init(id: "receiving_yards", label: "Receiving Yards"),
        .init(id: "receiving_tds", label: "Receiving TDs"),
    ]

    static let defense: [PlayerStatColumnDef] = [
        .init(id: "tackles_solo", label: "Solo Tackles"),
        .init(id: "tackles_assist", label: "Assisted Tackles"),
        .init(id: "sacks", label: "Sacks"),
        .init(id: "tackles_for_loss", label: "Tackles for Loss"),
        .init(id: "qb_hits", label: "QB Hits"),
        .init(id: "interceptions", label: "Interceptions"),
        .init(id: "passes_defended", label: "Passes Defended"),
        .init(id: "forced_fumbles", label: "Forced Fumbles"),
        .init(id: "fumble_recoveries", label: "Fumble Recoveries"),
        .init(id: "defensive_tds", label: "Defensive TDs"),
    ]

    static let specialTeams: [PlayerStatColumnDef] = [
        .init(id: "fg_attempts", label: "FG Attempts"),
        .init(id: "fg_made", label: "FG Made"),
        .init(id: "longest_fg", label: "Longest FG"),
        .init(id: "xp_attempts", label: "XP Attempts"),
        .init(id: "xp_made", label: "XP Made"),
        .init(id: "punts", label: "Punts"),
        .init(id: "punt_yards", label: "Punt Yards"),
        .init(id: "punt_avg", label: "Punt Avg"),
        .init(id: "kick_return_yards", label: "Kick Return Yards"),
        .init(id: "punt_return_yards", label: "Punt Return Yards"),
        .init(id: "return_tds", label: "Return TDs"),
    ]

    static func forPositionGroup(_ group: String) -> [PlayerStatColumnDef] {
        switch group {
        case "offense": return offense
        case "defense": return defense
        case "special_teams": return specialTeams
        default: return []
        }
    }
}

// MARK: - Split filter option lists (mirrors splits.js)

enum PlayerSplitOptions {
    static let gameSlots: [(value: String, label: String)] = [
        ("sunday_early", "Sunday Early"),
        ("sunday_late", "Sunday Late"),
        ("sunday_night", "Sunday Night"),
        ("monday_night", "Monday Night"),
        ("thursday_night", "Thursday Night"),
        ("thanksgiving", "Thanksgiving"),
        ("saturday", "Saturday"),
        ("other", "Other"),
    ]

    static let weather: [(value: String, label: String)] = [
        ("sunny", "Sunny"),
        ("overcast", "Overcast"),
        ("rain", "Rain"),
        ("snow", "Snow"),
        ("dome", "Dome"),
    ]
}

// MARK: - Scope definitions (mirrors PlayerDetailPage.jsx's SCOPES)

struct PlayerStatScope: Identifiable, Equatable {
    let id: String
    let label: String
}

enum PlayerStatScopes {
    static let all: [PlayerStatScope] = [
        .init(id: "season", label: "Season Avg"),
        .init(id: "season_total", label: "Season Total"),
        .init(id: "last5", label: "Last 5 Games"),
        .init(id: "career", label: "Career"),
        .init(id: "game_log", label: "Game Log"),
    ]
}

// MARK: - Display formatting

enum PlayerQueryDisplay {
    /// Matches PlayerDetailPage.jsx's StatGrid value formatting exactly:
    /// nil -> "—"; a whole number -> plain integer (no ".0"); anything
    /// else -> exactly one decimal place. Deliberately NOT the same
    /// convention as PortfolioFormat.number (JS-default-toString-trim)
    /// or GamePlayerStatsSection's own statText(_:) (always .1f for avg
    /// mode) -- this is its own, separately-verified rounding rule.
    static func statGridValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value == value.rounded() { return String(Int(value)) }
        return String(format: "%.1f", value)
    }

    /// GameLogTable shows RAW values (`row[key] ?? '—'`), no reformatting
    /// -- an Int column displays as-is.
    static func rawInt(_ value: Int?) -> String {
        guard let value else { return "—" }
        return String(value)
    }

    /// The two NUMERIC(_,1)-scale columns (defense.sacks, special_teams.
    /// punt_avg) arrive from Postgres as a JSON STRING (e.g. "0.5",
    /// "42.0") and web renders that string as-is, trailing zero and all
    /// -- %.1f reproduces that exactly since both columns are declared
    /// at scale 1, so Postgres's own string form is always X.Y.
    static func rawLenientDouble(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }
}

/// Mirrors EmptyStatsMessage.jsx's 4-branch copy exactly (verified
/// against that file line-for-line rather than paraphrased).
enum PlayerStatsEmptyMessage {
    static func text(scope: String, season: Int, hasActiveSplit: Bool, playerName: String) -> String {
        if scope == "career" {
            return "No career stats on file for \(playerName) yet — likely a rookie, or a player without tracked game history (our data covers the 2021–2025 seasons)."
        } else if hasActiveSplit {
            return "No games match these filters for the \(season) season — try clearing a split or picking a different season."
        } else if season == 2026 {
            return "The 2026 season hasn't been played yet — stats will appear here once games are tracked."
        } else {
            return "No recorded games for \(playerName) in \(season) — they may not have been on an NFL roster that season."
        }
    }
}
