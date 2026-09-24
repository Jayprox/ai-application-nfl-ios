//
//  Endpoints.swift
//  Chalk That NFL
//
//  Route constants for backend-api (ai-application-nfl repo). Base URL
//  is the real deployed API from that repo's README.md ("API:" line) —
//  swap to a localhost:PORT value for local backend dev if needed.
//
//  Only Auth is listed for now — each screen adds its own route
//  constants here as it's built, matching backend-api's real mounts in
//  backend/server.js (verified against that file directly, not just the
//  build brief's route table, since the brief itself says to treat that
//  table as a map, not a spec).
//
import Foundation

enum Endpoints {
    static let baseURL = "https://backend-api-production-15ce.up.railway.app"

    // MARK: - Auth (backend/routes/auth.js — public, no bearer token required)
    static let login   = "/login"
    static let refresh = "/refresh"
    static let logout  = "/logout"

    // MARK: - Teams (backend/routes/teams.js)
    static let teams = "/teams"
    static func team(_ id: Int) -> String { "/teams/\(id)" }

    // MARK: - Players (backend/routes/players.js)
    static func players(name: String?, team: String?, positionGroup: String?, activeOnly: Bool) -> String {
        var items: [URLQueryItem] = []
        if let name, !name.isEmpty { items.append(URLQueryItem(name: "name", value: name)) }
        if let team, !team.isEmpty { items.append(URLQueryItem(name: "team", value: team)) }
        if let positionGroup, !positionGroup.isEmpty {
            items.append(URLQueryItem(name: "position_group", value: positionGroup))
        }
        if activeOnly { items.append(URLQueryItem(name: "active_only", value: "true")) }

        var components = URLComponents()
        components.queryItems = items.isEmpty ? nil : items
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        return "/players\(query)"
    }
    static func player(_ id: String) -> String { "/players/\(id)" }

    // MARK: - Games (backend/routes/games.js)
    static let gamesCurrentWeek = "/games/current-week"
    static func games(season: Int, week: Int) -> String { "/games?season=\(season)&week=\(week)" }
    static func game(_ id: String) -> String { "/games/\(id)" }
    static func gameInjuries(_ id: String) -> String { "/games/\(id)/injuries" }
    /// GET /games/:id/boxscore — this GAME's actual played stat lines
    /// per roster, split {offense, defense, special_teams}. Returns
    /// `data: null` (not 404) before kickoff.
    static func gameBoxscore(_ id: String) -> String { "/games/\(id)/boxscore" }
    /// GET /games/:id/player-stats — both rosters' SEASON stats (not
    /// this-game stats), each stat category carrying both {avg, total}
    /// row sets. `data` is never null here.
    static func gamePlayerStats(_ id: String) -> String { "/games/\(id)/player-stats" }
    /// GET /games/:id/drives — drive-by-drive play-by-play. Returns
    /// `data: null` (not 404) before kickoff.
    static func gameDrives(_ id: String) -> String { "/games/\(id)/drives" }

    // MARK: - Edge (backend/routes/edge.js) — GET /edge?season=&week=&
    // only_disagreements= (Board's Top Edges preview AND the full Edge
    // tab's own list), plus GET /edge/games/:id for GameDetailView's
    // "Model vs. Market" section.
    static func edge(season: Int, week: Int, onlyDisagreements: Bool) -> String {
        var items = [
            URLQueryItem(name: "season", value: String(season)),
            URLQueryItem(name: "week", value: String(week)),
        ]
        if onlyDisagreements { items.append(URLQueryItem(name: "only_disagreements", value: "true")) }
        var components = URLComponents()
        components.queryItems = items
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        return "/edge\(query)"
    }
    static func gameEdge(_ gameId: String) -> String { "/edge/games/\(gameId)" }

    // MARK: - Odds (backend/routes/odds.js) — every synced
    // bookmaker/market for one game. Genuinely separate from the Edge
    // read above (own market grouping/bookmaker-name/point-formatting
    // logic, none of which Board's DK-only OddsBadge reuses).
    static func gameOdds(_ gameId: String) -> String { "/odds/games/\(gameId)" }

    // MARK: - Odds (backend/routes/odds.js) — Board's whole-slate view
    // only, via GET /odds?season=&week=. GET /odds/games/:id isn't
    // called yet.
    static func odds(season: Int, week: Int) -> String {
        "/odds?season=\(season)&week=\(week)"
    }

    // MARK: - Rankings (backend/routes/rankings.js) — Board pins
    // stat_category to passing_yards with limit=5 and always passes a
    // week; the full Rankings tab's own page lets week be blank (whole-
    // season top N, same as RankingsPage.jsx's own optional week field),
    // hence `week: Int?` here rather than a second overload.
    static func rankings(statCategory: String, season: Int, week: Int?, limit: Int) -> String {
        var query = "stat_category=\(statCategory)&season=\(season)"
        if let week { query += "&week=\(week)" }
        query += "&limit=\(limit)"
        return "/rankings?\(query)"
    }

    // MARK: - Props (backend/routes/props.js) — this week's DraftKings
    // player prop lines with recent-form context + deterministic lean.
    static func props(season: Int, week: Int) -> String {
        "/props/players?season=\(season)&week=\(week)"
    }

    // MARK: - Portfolio (backend/routes/portfolio.js) — POST
    // /portfolio/slate?season=&week=&max_picks=&unit_size=&dry_run= —
    // the whole request lives in the query string, no JSON body (see
    // APIClient's no-body post<T> overload). Builds (and, unless
    // dry_run=true, logs to picks_log) a slate of game-line picks.
    static func portfolioSlate(season: Int, week: Int, maxPicks: Int?, unitSize: Double?, dryRun: Bool) -> String {
        var items = [
            URLQueryItem(name: "season", value: String(season)),
            URLQueryItem(name: "week", value: String(week)),
            URLQueryItem(name: "dry_run", value: dryRun ? "true" : "false"),
        ]
        if let maxPicks { items.append(URLQueryItem(name: "max_picks", value: String(maxPicks))) }
        if let unitSize { items.append(URLQueryItem(name: "unit_size", value: Endpoints.formatUnitSize(unitSize))) }
        var components = URLComponents()
        components.queryItems = items
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        return "/portfolio/slate\(query)"
    }

    // MARK: - Picks (backend/routes/picks.js) — read-only view onto
    // picks_log. PicksViewModel always scopes to agent_name=
    // portfolio_agent_v1 (matches PicksPage.jsx's own hardcoded scope,
    // the only real writer today), hence no other filter params here
    // yet — status/game_id/player_id aren't used by any screen so far.
    static func picks(agentName: String) -> String {
        "/picks?agent_name=\(agentName)"
    }
    static func picksStats(agentName: String) -> String {
        "/picks/stats?agent_name=\(agentName)"
    }

    // MARK: - Leaderboard (backend/routes/leaderboard.js) — no params.
    static let leaderboard = "/leaderboard"

    /// Matches JS's default Number-to-string formatting (no trailing
    /// ".0" for a whole number) — the backend's own unit_size regex
    /// (`/^\d+(\.\d+)?$/`) accepts either shape, but this keeps the
    /// query string looking the same as what web would send.
    private static func formatUnitSize(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return String(value)
    }

    // MARK: - Chat (backend/routes/chat.js) — POST /chat, { messages:
    // [{role, content}] } -> { data: { role: "assistant", content } }.
    // Stateless: the client resends the whole (bounded) visible
    // conversation every message, same as ChatPage.jsx's own design.
    static let chat = "/chat"

    // MARK: - Query (backend/routes/query.js) — POST /query, the shared
    // stats engine behind PlayerDetailView's stat tabs (season/
    // season_total/last5/career/game_log scopes, home_away/game_slot/
    // weather splits). Body-only endpoint -- see PlayerQueryModels.swift.
    static let query = "/query"

    // MARK: - Insights (backend/routes/insights.js) — GET
    // /insights/players/:id?season=, the deterministic matchup/recent-
    // form/situational/role-trend label layer. See PlayerInsightModels.swift.
    static func playerInsights(_ playerId: String, season: Int) -> String {
        "/insights/players/\(playerId)?season=\(season)"
    }

    // MARK: - Query / etc.
    // Added as each screen is built (see build order in HANDOFF.md).
}
