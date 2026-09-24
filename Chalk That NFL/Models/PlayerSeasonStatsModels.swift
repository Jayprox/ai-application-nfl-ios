//
//  PlayerSeasonStatsModels.swift
//  Chalk That NFL
//
//  Wire models for GET /games/:gameId/player-stats (backend/routes/
//  games.js) — both rosters' SEASON stats (not this-game stats), split
//  into { home, away } and grouped into { offense, defense,
//  special_teams } like BoxScoreModels.swift, but each category carries
//  BOTH { avg, total } row sets (a season average and a season total
//  per player) rather than one.
//
//  Every stat column here — including sacks/punt_avg, which need
//  lenient decoding in BoxScoreModels.swift — is explicitly cast
//  `::float8` server-side (see that route's avgSelects/totalSelects),
//  so this whole file is plain synthesized Decodable: every stat column
//  decodes as a real JSON Double, never a NUMERIC-as-string. Modeled as
//  Double? (not Double) since AVG()/SUM() over an all-null group (e.g.
//  a receiver's pass_attempts) is a real SQL NULL, matching web's own
//  `r[key] ?? 0` display fallback.
//
//  Display precision is a deliberate CHOICE, not a parity requirement,
//  worth flagging: web's own JSX renders these raw floats with zero
//  formatting (`{r[key] ?? 0}`), which for an average like 24.5/6 can
//  come back as a long, ugly float (Postgres AVG's default numeric
//  scale, then a float8 cast doesn't round it further). The views that
//  render these values round for display (1 decimal for Season Avg,
//  trimmed-trailing-zero for Season Total — same convention
//  PortfolioFormat.number/PropGradingLogic.formatLine already use
//  elsewhere) rather than reproducing that raw-float artifact — this
//  changes how the number LOOKS, never the number a query returned.
//
import Foundation

struct PlayerSeasonOffenseRow: Decodable, Identifiable, Hashable {
    var id: String { playerId }
    let playerId: String
    let teamId: Int
    let fullName: String
    let position: String
    let gamesPlayed: Int
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
}

struct PlayerSeasonDefenseRow: Decodable, Identifiable, Hashable {
    var id: String { playerId }
    let playerId: String
    let teamId: Int
    let fullName: String
    let position: String
    let gamesPlayed: Int
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
}

struct PlayerSeasonSpecialTeamsRow: Decodable, Identifiable, Hashable {
    var id: String { playerId }
    let playerId: String
    let teamId: Int
    let fullName: String
    let position: String
    let gamesPlayed: Int
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
}

struct PlayerSeasonCategoryPair<Row: Decodable>: Decodable {
    let avg: [Row]
    let total: [Row]
}

struct PlayerSeasonTeamSplit: Decodable {
    let offense: PlayerSeasonCategoryPair<PlayerSeasonOffenseRow>
    let defense: PlayerSeasonCategoryPair<PlayerSeasonDefenseRow>
    let specialTeams: PlayerSeasonCategoryPair<PlayerSeasonSpecialTeamsRow>
}

struct PlayerSeasonSides: Decodable {
    let home: PlayerSeasonTeamSplit
    let away: PlayerSeasonTeamSplit
}

struct PlayerSeasonFreshness: Decodable {
    let syncedAt: String?
}

struct PlayerSeasonMeta: Decodable {
    let sampleSize: Int
    let freshness: PlayerSeasonFreshness?
}

/// Unlike BoxScoreResponse, `data` is never null here — this route has
/// no "game hasn't started yet" branch (a season aggregate is available
/// for an upcoming game too, that's the whole point of this section
/// existing separately from Live Box Score). An empty roster's season
/// still shows up as `meta.sample_size == 0` with empty row arrays.
struct PlayerSeasonStatsResponse: Decodable {
    let data: PlayerSeasonSides
    let meta: PlayerSeasonMeta
}
