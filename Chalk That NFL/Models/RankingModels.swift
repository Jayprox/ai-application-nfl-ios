//
//  RankingModels.swift
//  Chalk That NFL
//
//  Wire model for backend/routes/rankings.js's GET /rankings (backend/
//  lib/ranking.js's rankMatchups()) — matchup_scores rows returned
//  straight from SQL with no server-side Number() coercion (unlike
//  edge.js), so `score`/`seasonAvg` are Postgres NUMERIC columns that
//  arrive as JSON strings — see Extensions/Decoding+Lenient.swift.
//  `breakdown` (JSONB — the 4-category detail behind the score) isn't
//  modeled — confirmed RankingsPage.jsx's own full table doesn't
//  display it either (just rank/name/position/score/categories_used/
//  season_avg, same fields Board's curated preview already used), so
//  there's genuinely nothing on either page that needs it yet.
//
import Foundation

/// Web's STAT_CATEGORY_LABEL/STAT_CATEGORY_UNIT — matches
/// backend/lib/ranking.js's STAT_CATEGORIES exactly (four values; the
/// route 400s on anything else).
enum RankingStatCategory: String, CaseIterable, Identifiable {
    case passingYards = "passing_yards"
    case rushingYards = "rushing_yards"
    case receivingYards = "receiving_yards"
    case tackles = "tackles"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .passingYards: return "Passing yards"
        case .rushingYards: return "Rushing yards"
        case .receivingYards: return "Receiving yards"
        case .tackles: return "Tackles"
        }
    }

    /// Short unit suffix for the season-avg column, matching web's
    /// STAT_CATEGORY_UNIT.
    var unit: String {
        switch self {
        case .passingYards: return "pass yds/gm"
        case .rushingYards: return "rush yds/gm"
        case .receivingYards: return "rec yds/gm"
        case .tackles: return "tkl/gm"
        }
    }
}

struct RankingRow: Decodable, Identifiable {
    var id: String { "\(playerId)-\(gameId)" }
    let rank: Int
    let playerId: String
    let playerName: String
    let position: String
    let gameId: String
    let score: Double
    let categoriesUsed: Int
    let gamesPlayed: Int?
    let seasonAvg: Double?

    private enum CodingKeys: String, CodingKey {
        case rank, playerId, playerName, position, gameId
        case score, categoriesUsed, gamesPlayed, seasonAvg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rank = try container.decode(Int.self, forKey: .rank)
        playerId = try container.decode(String.self, forKey: .playerId)
        playerName = try container.decode(String.self, forKey: .playerName)
        position = try container.decode(String.self, forKey: .position)
        gameId = try container.decode(String.self, forKey: .gameId)
        score = try container.decodeLenientDouble(forKey: .score)
        categoriesUsed = try container.decode(Int.self, forKey: .categoriesUsed)
        gamesPlayed = try container.decodeIfPresent(Int.self, forKey: .gamesPlayed)
        seasonAvg = try container.decodeLenientDoubleIfPresent(forKey: .seasonAvg)
    }
}

/// GET /rankings's top-level envelope — not the shared APIEnvelope<T>,
/// since `meta.freshness.synced_at` (when matchup_scores was last
/// computed) is genuinely shown in the UI (RankingsPage.jsx's own
/// footer), same reasoning PropsResponse already documents for its own
/// meta. `count`/`limit`/`stat_category` are all trivially re-derivable
/// client-side (the array's own count, the active picker state) so only
/// `freshness` actually needs modeling, but the full shape is kept here
/// for clarity/future use rather than only picking out one field.
struct RankingsResponse: Decodable {
    let data: [RankingRow]
    let meta: RankingsMeta
}

struct RankingsMeta: Decodable {
    let statCategory: String
    let count: Int
    let limit: Int
    let freshness: RankingsFreshness
}

struct RankingsFreshness: Decodable {
    let syncedAt: String?
}
