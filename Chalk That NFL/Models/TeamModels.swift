//
//  TeamModels.swift
//  Chalk That NFL
//
//  Wire models for backend/routes/teams.js.
//
import Foundation

struct Team: Decodable, Identifiable, Hashable {
    var id: Int { teamId }
    let teamId: Int
    let abbreviation: String
    let name: String
    let conference: String
    let division: String
    let stadiumId: Int?
    let stadiumName: String?
    let city: String?
    let state: String?
    let roof: String?
    let surface: String?
}

/// GET /teams/:id — same team fields plus its current roster (active +
/// injured reserve, already filtered server-side — see that route's own
/// header comment for exactly which statuses/freshness window).
struct TeamDetail: Decodable {
    let teamId: Int
    let abbreviation: String
    let name: String
    let conference: String
    let division: String
    let stadiumName: String?
    let city: String?
    let state: String?
    let roof: String?
    let surface: String?
    let roster: [RosterPlayer]
}

struct RosterPlayer: Decodable, Identifiable, Hashable {
    var id: String { playerId }
    let playerId: String
    let fullName: String
    let position: String
    let positionGroup: String
    /// 'ACT' or 'RES' (injured reserve) — the only two statuses this
    /// route can return (backend/routes/teams.js filters to these).
    let status: String
}
