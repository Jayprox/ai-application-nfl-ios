//
//  RosterPositions.swift
//  Chalk That NFL
//
//  Mirrors frontend/src/constants/rosterPositions.js exactly — same
//  bucket order and raw-position-code mapping, so Team Detail's roster
//  groups match web's depth-chart-style layout (QB/RB/WR/TE/OL,
//  DL/LB/CB/S, K/P/LS) rather than the coarser offense/defense/
//  special_teams split.
//
import Foundation

enum RosterPositions {
    static let order = ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S", "K", "P", "LS"]

    static let label: [String: String] = [
        "QB": "Quarterbacks",
        "RB": "Running Backs",
        "WR": "Wide Receivers",
        "TE": "Tight Ends",
        "OL": "Offensive Line",
        "DL": "Defensive Line",
        "LB": "Linebackers",
        "CB": "Cornerbacks",
        "S": "Safeties",
        "K": "Kickers",
        "P": "Punters",
        "LS": "Long Snappers",
    ]

    private static let rawToBucket: [String: String] = [
        "QB": "QB",
        "RB": "RB", "FB": "RB", "HB": "RB",
        "WR": "WR",
        "TE": "TE",
        "T": "OL", "G": "OL", "C": "OL", "OT": "OL", "OG": "OL", "OL": "OL",
        "DE": "DL", "DT": "DL", "NT": "DL", "DL": "DL", "EDGE": "DL",
        "LB": "LB", "ILB": "LB", "OLB": "LB", "MLB": "LB",
        "CB": "CB", "DB": "CB", "NB": "CB",
        "S": "S", "SS": "S", "FS": "S", "SAF": "S",
        "K": "K", "KR": "K", "PR": "K",
        "P": "P",
        "LS": "LS",
    ]

    static func bucket(for position: String) -> String {
        let pos = position.uppercased()
        return rawToBucket[pos] ?? pos
    }
}

enum PositionGroup {
    static let order = ["offense", "defense", "special_teams"]
    static let label: [String: String] = [
        "offense": "Offense",
        "defense": "Defense",
        "special_teams": "Special Teams",
    ]
}
