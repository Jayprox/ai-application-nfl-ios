//
//  LeaderboardModels.swift
//  Chalk That NFL
//
//  Wire model for backend/routes/leaderboard.js — GET /leaderboard, no
//  params. Every agent writing to picks_log, ranked by hit rate
//  (nulls — zero decided picks — sort last, never zeroth; see that
//  route's own sort comparator comment). Deliberately no PNL column:
//  picks_log stores no price at pick time, so a payout can't be
//  computed (leaderboard.js's own header explains why this is the
//  honest metric available, not a placeholder for one that's missing).
//
//  Every field here is server-side Number()-wrapped identically to
//  PicksStats, so this is plain synthesized Decodable — no lenient
//  decoding needed.
//
import Foundation

struct LeaderboardEntry: Decodable, Identifiable, Hashable {
    var id: String { agentName }

    let rank: Int
    let agentName: String
    let total: Int
    let pending: Int
    let correct: Int
    let incorrect: Int
    let push: Int
    let void: Int
    let decided: Int
    let hitRatePct: Double?
}

struct LeaderboardResponse: Decodable {
    let data: [LeaderboardEntry]
    let meta: LeaderboardMeta
}

struct LeaderboardMeta: Decodable {
    let agentCount: Int
}
