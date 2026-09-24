//
//  OddsModels.swift
//  Chalk That NFL
//
//  Wire models for backend/routes/odds.js's GET /odds?season=&week=
//  (the whole-slate view Board uses; GET /odds/games/:id isn't called
//  yet — no screen needs a single game's odds in isolation until a
//  later phase). Every price/point column is Postgres NUMERIC with no
//  ::float8 cast (db/migrations/003_game_odds.sql, widened by 009), so
//  the `pg` driver hands them back as JSON strings — see
//  Extensions/Decoding+Lenient.swift, first hit on GameModels.swift's
//  weather fields.
//
import Foundation

struct BookmakerLine: Decodable {
    let bookmaker: String
    /// "h2h" | "spreads" | "totals" | "team_totals"
    let market: String
    let homePrice: Double?
    let awayPrice: Double?
    let homePoint: Double?
    let awayPoint: Double?
    let overPrice: Double?
    let underPrice: Double?
    let totalPoint: Double?
    /// 'team_totals' only ("home"/"away") — always nil for every other
    /// market. Not read by OddsBadge (mirrors web: GameCard/OddsBadge
    /// never renders team_totals either), modeled here only so decode
    /// doesn't silently drop the field.
    let teamSide: String?
    let bookmakerLastUpdate: String?
    let syncedAt: String?

    private enum CodingKeys: String, CodingKey {
        case bookmaker, market
        case homePrice, awayPrice, homePoint, awayPoint
        case overPrice, underPrice, totalPoint
        case teamSide, bookmakerLastUpdate, syncedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookmaker = try container.decode(String.self, forKey: .bookmaker)
        market = try container.decode(String.self, forKey: .market)
        homePrice = try container.decodeLenientDoubleIfPresent(forKey: .homePrice)
        awayPrice = try container.decodeLenientDoubleIfPresent(forKey: .awayPrice)
        homePoint = try container.decodeLenientDoubleIfPresent(forKey: .homePoint)
        awayPoint = try container.decodeLenientDoubleIfPresent(forKey: .awayPoint)
        overPrice = try container.decodeLenientDoubleIfPresent(forKey: .overPrice)
        underPrice = try container.decodeLenientDoubleIfPresent(forKey: .underPrice)
        totalPoint = try container.decodeLenientDoubleIfPresent(forKey: .totalPoint)
        teamSide = try container.decodeIfPresent(String.self, forKey: .teamSide)
        bookmakerLastUpdate = try container.decodeIfPresent(String.self, forKey: .bookmakerLastUpdate)
        syncedAt = try container.decodeIfPresent(String.self, forKey: .syncedAt)
    }
}

/// One game's odds across every synced bookmaker/market — GET /odds's
/// list shape groups rows by game_id server-side already.
struct GameOdds: Decodable {
    let gameId: String
    let bookmakers: [BookmakerLine]
}
