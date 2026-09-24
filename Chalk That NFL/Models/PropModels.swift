//
//  PropModels.swift
//  Chalk That NFL
//
//  Wire models for backend/routes/props.js's GET /props/players?
//  season=&week= — this week's DraftKings-only player prop lines, each
//  with real recent-form context (last-5-game average vs. the line, a
//  plain descriptive ratio) and a deterministic lean (over/under/toss-
//  up) — explicitly NOT a simulation or confidence score (see that
//  route's own header comment). Deliberately mirrors PropsPage.jsx's
//  own data shape rather than reshaping anything client-side.
//
//  `line`/`overPrice`/`underPrice` come straight off player_prop_odds's
//  NUMERIC(6,1)/NUMERIC(7,2) columns with no server-side Number() cast
//  (db/migrations/012_player_prop_odds.sql) — same NUMERIC-as-string
//  situation as game_odds/GameModels, so these need lenient decoding
//  (Extensions/Decoding+Lenient.swift). `finalValue`/`context.recentAvg`/
//  `context.tdRate`/`edgePct`, by contrast, ARE all explicitly wrapped in
//  Number() server-side (see props.js's attachContext/leanFromAverage/
//  leanFromTdRate) before res.json(), so those decode as plain JSON
//  numbers — no lenient decoding needed for them.
//
import Foundation

struct PropPlayer: Decodable, Hashable {
    let playerId: String
    let fullName: String
    let position: String
    /// players.current_team_id is nullable (a player between teams).
    let teamId: Int?
}

struct PropContext: Decodable, Hashable {
    /// Last-5-game average for the market's stat column. Always nil for
    /// player_anytime_td (no single stat column to average — see tdRate
    /// below instead).
    let recentAvg: Double?
    let gamesPlayed: Int
    /// Fraction of the last 5 games with any TD (rush+rec+pass combined).
    /// Only populated for player_anytime_td; nil for the 4 yardage/
    /// receptions markets.
    let tdRate: Double?
}

struct PropRow: Decodable, Identifiable, Hashable {
    var id: String { "\(gameId)-\(player.playerId)-\(market)-\(bookmaker)" }
    let gameId: String
    /// "player_pass_yds" | "player_rush_yds" | "player_reception_yds" |
    /// "player_receptions" | "player_anytime_td"
    let market: String
    let marketLabel: String
    /// Always "draftkings" — props.js filters to DK only (see that
    /// route's header comment on the single-bookmaker convention).
    let bookmaker: String
    /// NULL for player_anytime_td (a Yes/No prop, not an Over/Under
    /// one) — see 012_player_prop_odds.sql's header comment.
    let line: Double?
    /// For player_anytime_td, reused as the "Yes" price.
    let overPrice: Double?
    /// For player_anytime_td, reused as the "No" price.
    let underPrice: Double?
    let bookmakerLastUpdate: String?
    let syncedAt: String?
    /// "scheduled" | "in_progress" | "final" | "postponed"
    let gameStatus: String
    let player: PropPlayer
    /// Only non-nil once gameStatus == "final" — the player's real,
    /// single-game stat line for THIS game (already COALESCEd to 0 for
    /// a real box-score row with a missing stat group — see props.js's
    /// 2026-09-18 "TOSS-UP badges never finalize" fix comment). Still
    /// nil when there's no box-score row at all for this player/game
    /// (DNP, inactive, unresolved vendor name) — a genuine void, not a
    /// false zero.
    let finalValue: Double?
    let context: PropContext
    /// "over" | "under" | "toss_up" | nil (nil = not enough recent-form
    /// sample to read either way).
    let lean: String?
    let reasoning: String?
    /// Plain descriptive ratio (how far recent form clears the line) —
    /// NOT a probability/confidence score. Used only for in-game sort
    /// order, same as PropsPage.jsx's own leanSortKey().
    let edgePct: Double?

    private enum CodingKeys: String, CodingKey {
        case gameId, market, marketLabel, bookmaker, line, overPrice, underPrice
        case bookmakerLastUpdate, syncedAt, gameStatus, player, finalValue
        case context, lean, reasoning, edgePct
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameId = try container.decode(String.self, forKey: .gameId)
        market = try container.decode(String.self, forKey: .market)
        marketLabel = try container.decode(String.self, forKey: .marketLabel)
        bookmaker = try container.decode(String.self, forKey: .bookmaker)
        line = try container.decodeLenientDoubleIfPresent(forKey: .line)
        overPrice = try container.decodeLenientDoubleIfPresent(forKey: .overPrice)
        underPrice = try container.decodeLenientDoubleIfPresent(forKey: .underPrice)
        bookmakerLastUpdate = try container.decodeIfPresent(String.self, forKey: .bookmakerLastUpdate)
        syncedAt = try container.decodeIfPresent(String.self, forKey: .syncedAt)
        gameStatus = try container.decode(String.self, forKey: .gameStatus)
        player = try container.decode(PropPlayer.self, forKey: .player)
        finalValue = try container.decodeIfPresent(Double.self, forKey: .finalValue)
        context = try container.decode(PropContext.self, forKey: .context)
        lean = try container.decodeIfPresent(String.self, forKey: .lean)
        reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning)
        edgePct = try container.decodeIfPresent(Double.self, forKey: .edgePct)
    }
}

/// GET /props/players's top-level envelope — not the shared
/// APIEnvelope<T> (which only ever captures `data`), since this
/// endpoint's `meta` (sample_size + freshness.synced_at) is actually
/// shown in the UI (PropsPage.jsx's footer line), unlike Board's other
/// list endpoints where meta is fetched but never displayed.
struct PropsResponse: Decodable {
    let data: [PropRow]
    let meta: PropsMeta
}

struct PropsMeta: Decodable {
    let sampleSize: Int
    let freshness: PropsFreshness
}

struct PropsFreshness: Decodable {
    let syncedAt: String?
}
