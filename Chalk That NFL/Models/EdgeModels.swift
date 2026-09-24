//
//  EdgeModels.swift
//  Chalk That NFL
//
//  Wire model for backend/routes/edge.js's GET /edge?season=&week=
//  (backend/lib/edge.js's compareGameEdge()). Every numeric field in
//  that response is explicitly `Number()`-coerced server-side before
//  being put on the JSON object (see edge.js's own comments —
//  teamOffenseLean, marketFavorite, and the model_margin/market_margin
//  math all wrap their Postgres-sourced values in Number() before they
//  reach res.json()), so these decode as plain JSON numbers, not
//  NUMERIC-as-string like games/odds — no lenient decoding needed here.
//
//  model_favorite/model_margin/market_favorite/market_margin/
//  market_source are sometimes entirely ABSENT from the JSON object
//  (compareGameEdge's two early-return cases only set a subset of
//  keys), not just null — Swift's synthesized Decodable already treats
//  a missing key the same as an explicit null for an Optional
//  property, so plain optionals here handle both cases correctly
//  without a custom init.
//
import Foundation

struct EdgeLean: Decodable, Hashable {
    let avgScore: Double
    let playerCount: Int
}

struct EdgeRow: Decodable, Identifiable, Hashable {
    var id: String { gameId }
    let gameId: String
    let homeTeamId: Int
    let awayTeamId: Int
    let homeLean: EdgeLean?
    let awayLean: EdgeLean?
    /// "home" | "away" | nil
    let modelFavorite: String?
    let modelMargin: Double?
    /// "home" | "away" | nil
    let marketFavorite: String?
    let marketMargin: Double?
    /// "spreads" | "h2h" | nil
    let marketSource: String?
    /// true = model and market disagree ("worth a closer look"), false =
    /// they agree, nil = not enough signal to compare either way.
    let edge: Bool?
    let note: String
}
