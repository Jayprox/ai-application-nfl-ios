//
//  PlayerModels.swift
//  Chalk That NFL
//
//  Wire models for backend/routes/players.js. Deliberately has no stat
//  fields — backend-api keeps identity/bio (this route) and stats
//  (POST /query) as separate concerns on purpose (see that route's own
//  header comment); Player Detail's stat display is a follow-up, not
//  part of this pass.
//
import Foundation

struct PlayerSummary: Decodable, Identifiable, Hashable {
    var id: String { playerId }
    let playerId: String
    let fullName: String
    let position: String
    let positionGroup: String
    let status: String
    let teamId: Int?
    let teamAbbreviation: String?
}

struct PlayerInjury: Decodable, Hashable {
    let reportStatus: String?
    let practiceStatus: String?
    let primaryInjury: String?
    let secondaryInjury: String?
    let reportDate: String?
}

struct PlayerDetail: Decodable {
    let playerId: String
    let fullName: String
    let position: String
    let positionGroup: String
    let status: String
    let birthDate: String?
    let draftYear: Int?
    let draftRound: Int?
    let draftPick: Int?
    let teamId: Int?
    let teamAbbreviation: String?
    let teamName: String?
    let currentInjury: PlayerInjury?
}
