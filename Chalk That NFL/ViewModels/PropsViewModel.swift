//
//  PropsViewModel.swift
//  Chalk That NFL
//
//  Mirrors PropsPage.jsx's three reads: GET /games/current-week
//  (resolves season/week), GET /games?season=&week= (purely for each
//  group's away/home matchup header + kickoff — the props response
//  itself only ever carries game_id), and GET /props/players?season=&
//  week= (the actual prop lines). No manual week picker — web's own
//  Props page doesn't have one either, it always just shows the
//  resolved current week.
//
import Foundation
import Combine

@MainActor
final class PropsViewModel: ObservableObject {
    @Published private(set) var season: Int?
    @Published private(set) var week: Int?
    @Published var activeMarket: PropMarket = .passYds

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    @Published private(set) var allProps: [PropRow] = []
    @Published private(set) var gamesById: [String: Game] = [:]
    @Published private(set) var sampleSize: Int = 0
    @Published private(set) var freshnessSyncedAt: String?

    private var didLoadOnce = false

    func loadIfNeeded() async {
        guard !didLoadOnce else { return }
        didLoadOnce = true
        await loadAll()
    }

    func refresh() async {
        await loadAll()
    }

    private func loadAll() async {
        await loadCurrentWeek()
        guard season != nil, week != nil else { return }
        async let propsResult: () = loadProps()
        async let gamesResult: () = loadGames()
        _ = await (propsResult, gamesResult)
    }

    private func loadCurrentWeek() async {
        do {
            let envelope: APIEnvelope<CurrentWeek> = try await APIClient.shared.get(Endpoints.gamesCurrentWeek)
            season = envelope.data.season
            week = envelope.data.week
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Couldn't resolve the current week."
        }
    }

    private func loadProps() async {
        guard let season, let week else { return }
        isLoading = true
        errorMessage = nil
        do {
            let response: PropsResponse = try await APIClient.shared.get(Endpoints.props(season: season, week: week))
            allProps = response.data
            sampleSize = response.meta.sampleSize
            freshnessSyncedAt = response.meta.freshness.syncedAt
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Couldn't load props."
        }
        isLoading = false
    }

    /// Only used for each group's own header (away @ home + kickoff) —
    /// same graceful-degradation web's separate useApiFetch(gamesPath)
    /// gets for free (a game missing from this lookup just falls back
    /// to showing the raw game id, per PropsPage.jsx's own `game ? ... :
    /// gameId` branch), so a failure here shouldn't block the props
    /// list itself.
    private func loadGames() async {
        guard let season, let week else { return }
        do {
            let envelope: APIEnvelope<[Game]> = try await APIClient.shared.get(Endpoints.games(season: season, week: week))
            gamesById = Dictionary(uniqueKeysWithValues: envelope.data.map { ($0.gameId, $0) })
        } catch {
            // Silently degrade, per the comment above.
        }
    }

    /// Web's gamesWithProps: this market's rows, grouped by game, each
    /// game's rows sorted by PropGradingLogic.sortKey, games themselves
    /// ordered by kickoff (earliest first; a game missing from
    /// gamesById sorts first too, same as web's `?? 0` epoch fallback).
    var groupedByGame: [PropGameGroup] {
        let marketProps = allProps.filter { $0.market == activeMarket.rawValue }
        var byGame: [String: [PropRow]] = [:]
        for prop in marketProps {
            byGame[prop.gameId, default: []].append(prop)
        }
        let groups = byGame.map { gameId, rows -> PropGameGroup in
            let sortedRows = rows.sorted(by: PropGradingLogic.isBefore)
            return PropGameGroup(gameId: gameId, game: gamesById[gameId], rows: sortedRows)
        }
        return groups.sorted { a, b in
            let da = a.game.flatMap { BackendDate.parse($0.gameDatetime) } ?? .distantPast
            let db = b.game.flatMap { BackendDate.parse($0.gameDatetime) } ?? .distantPast
            return da < db
        }
    }
}

struct PropGameGroup: Identifiable {
    var id: String { gameId }
    let gameId: String
    let game: Game?
    let rows: [PropRow]
}

/// Web's MARKET_TABS — this app's 5 launch markets (backend/routes/
/// props.js's MARKET_STAT_COLUMN + player_anytime_td).
enum PropMarket: String, CaseIterable, Identifiable {
    case passYds = "player_pass_yds"
    case rushYds = "player_rush_yds"
    case receptionYds = "player_reception_yds"
    case receptions = "player_receptions"
    case anytimeTd = "player_anytime_td"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .passYds: return "Pass Yds"
        case .rushYds: return "Rush Yds"
        case .receptionYds: return "Rec Yds"
        case .receptions: return "Receptions"
        case .anytimeTd: return "Anytime TD"
        }
    }
}
