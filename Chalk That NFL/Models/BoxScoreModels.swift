//
//  BoxScoreModels.swift
//  Chalk That NFL
//
//  Wire models for GET /games/:gameId/boxscore (backend/routes/games.js)
//  — both rosters' per-player stat lines for THIS game, split into
//  { home, away } and grouped into { offense, defense, special_teams }
//  (same three *_game_stats tables/columns lib/stats-query.js's
//  PLAYER_STAT_TABLES/PLAYER_STAT_COLUMNS define). Returns `data: null`
//  (not 404) for a game that hasn't kicked off yet — see
//  BoxScoreResponse's `data`/`meta` shape below.
//
//  Column types confirmed against db/schema.sql directly, not assumed:
//  every offense/defense/special_teams column is a plain INT EXCEPT
//  player_defense_game_stats.sacks (NUMERIC(3,1), partial-credit sacks
//  like 0.5) and player_special_teams_game_stats.punt_avg (NUMERIC(4,1))
//  — and this route casts neither, so those two need the usual
//  decodeLenientDoubleIfPresent treatment while every other column here
//  decodes as a plain Int (INT columns arrive as real JSON numbers, not
//  NUMERIC-as-string). Every stat column is nullable (a row only exists
//  per player per game, not per player per stat group), matching web's
//  own `r[key] ?? 0` display fallback.
//
import Foundation

struct BoxScoreOffenseRow: Decodable, Identifiable, Hashable {
    var id: String { playerId }
    let playerId: String
    let teamId: Int
    let fullName: String
    let position: String
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
}

struct BoxScoreDefenseRow: Decodable, Identifiable, Hashable {
    var id: String { playerId }
    let playerId: String
    let teamId: Int
    let fullName: String
    let position: String
    let tacklesSolo: Int?
    let tacklesAssist: Int?
    /// NUMERIC(3,1) — partial-credit sacks (e.g. 0.5). No cast in this
    /// route's SELECT, so lenient decoding is required.
    let sacks: Double?
    let tacklesForLoss: Int?
    let qbHits: Int?
    let interceptions: Int?
    let passesDefended: Int?
    let forcedFumbles: Int?
    let fumbleRecoveries: Int?
    let defensiveTds: Int?

    private enum CodingKeys: String, CodingKey {
        case playerId, teamId, fullName, position
        case tacklesSolo, tacklesAssist, sacks, tacklesForLoss, qbHits
        case interceptions, passesDefended, forcedFumbles, fumbleRecoveries, defensiveTds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try container.decode(String.self, forKey: .playerId)
        teamId = try container.decode(Int.self, forKey: .teamId)
        fullName = try container.decode(String.self, forKey: .fullName)
        position = try container.decode(String.self, forKey: .position)
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
}

struct BoxScoreSpecialTeamsRow: Decodable, Identifiable, Hashable {
    var id: String { playerId }
    let playerId: String
    let teamId: Int
    let fullName: String
    let position: String
    let fgAttempts: Int?
    let fgMade: Int?
    let longestFg: Int?
    let xpAttempts: Int?
    let xpMade: Int?
    let punts: Int?
    let puntYards: Int?
    /// NUMERIC(4,1) — no cast in this route's SELECT, needs lenient
    /// decoding (same reasoning as BoxScoreDefenseRow.sacks above).
    let puntAvg: Double?
    let kickReturnYards: Int?
    let puntReturnYards: Int?
    let returnTds: Int?

    private enum CodingKeys: String, CodingKey {
        case playerId, teamId, fullName, position
        case fgAttempts, fgMade, longestFg, xpAttempts, xpMade
        case punts, puntYards, puntAvg, kickReturnYards, puntReturnYards, returnTds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try container.decode(String.self, forKey: .playerId)
        teamId = try container.decode(Int.self, forKey: .teamId)
        fullName = try container.decode(String.self, forKey: .fullName)
        position = try container.decode(String.self, forKey: .position)
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
}

struct BoxScoreTeamSplit: Decodable {
    let offense: [BoxScoreOffenseRow]
    let defense: [BoxScoreDefenseRow]
    let specialTeams: [BoxScoreSpecialTeamsRow]
}

struct BoxScoreSides: Decodable {
    let home: BoxScoreTeamSplit
    let away: BoxScoreTeamSplit
}

struct BoxScoreFreshness: Decodable {
    let syncedAt: String?
}

struct BoxScoreMeta: Decodable {
    /// Absent when `data` is null (the "game hasn't started yet" branch
    /// only returns `{reason}`).
    let sampleSize: Int?
    let freshness: BoxScoreFreshness?
    let reason: String?
}

struct BoxScoreResponse: Decodable {
    let data: BoxScoreSides?
    let meta: BoxScoreMeta
}
