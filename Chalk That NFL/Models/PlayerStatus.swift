//
//  PlayerStatus.swift
//  Chalk That NFL
//
//  `players.status` is stored as an uppercase roster code — confirmed
//  against real usage across the backend-api repo: routes/teams.js and
//  routes/players.js both filter `status IN ('ACT', 'RES')` directly in
//  SQL, TeamDetailPage.jsx checks `player.status === 'RES'` for its IR
//  badge, and the full code set + labels come straight from
//  scripts/fantasy-auction-values.js's own ROSTER_STATUS_LABEL map.
//
//  NOTE: frontend/src/constants/playerStatus.js assumes a different,
//  lowercase-word status domain ("active", "injured_reserve", ...) and
//  is used by PlayerBrowsePage.jsx's status badge — that looks like
//  stale/dead code in web itself (it can't actually match any real
//  status value coming back from the API), not a second real
//  convention. Matching TeamDetailPage.jsx's literal 'RES' check
//  instead, since that's the one demonstrably working against real
//  data.
//
enum PlayerStatus {
    /// Empty string for ACT, matching ROSTER_STATUS_LABEL's own
    /// convention of "no label for the common case."
    static func label(_ code: String) -> String {
        switch code {
        case "ACT": return ""
        case "CUT": return "Cut"
        case "DEV": return "Practice Squad"
        case "RES": return "Reserve/IR"
        case "INA": return "Inactive"
        case "RET": return "Retired"
        case "EXE": return "Exempt List"
        default: return code
        }
    }
}
