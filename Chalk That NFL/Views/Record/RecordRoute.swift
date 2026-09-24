//
//  RecordRoute.swift
//  Chalk That NFL
//
//  Every screen under the Record tab shares ONE NavigationStack, rooted
//  in RecordHomeView — same "one Hashable route type per tab" pattern
//  AgentsRoute/ResearchRoute already established. Record groups Picks +
//  Leaderboard, matching web's own Layout.jsx RECORD_ITEMS grouping
//  (Portfolio itself lives under Agents, not here — see AgentsRoute.swift).
//
import Foundation

enum RecordRoute: Hashable {
    case picks
    case leaderboard
}
