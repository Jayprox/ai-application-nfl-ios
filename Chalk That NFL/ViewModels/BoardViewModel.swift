//
//  BoardViewModel.swift
//  Chalk That NFL
//
//  Mirrors BoardPage.jsx: five independent fetches gated by
//  GET /games/current-week, each with its OWN loading/error state (a
//  slow rankings query shouldn't hold up the games strip) except odds,
//  which is a silent nice-to-have overlay on web too — a failed odds
//  fetch just means no OddsBadge shows, never its own error UI.
//
import Foundation
import Combine

/// One day's worth of games for the "This Week's Games" section — the
/// key ("2026-09-18") drives sort order, heading ("Thursday, Sep 18")
/// is what's displayed. Distinct from KeyedGroup since it needs both.
struct BoardGameGroup: Identifiable {
    let id: String
    let heading: String
    let games: [Game]
}

@MainActor
final class BoardViewModel: ObservableObject {
    @Published private(set) var season: Int?
    @Published private(set) var week: Int?
    @Published private(set) var weekIsLoading = false
    @Published private(set) var weekErrorMessage: String?

    @Published private(set) var games: [Game] = []
    @Published private(set) var gamesIsLoading = false
    @Published private(set) var gamesErrorMessage: String?

    @Published private(set) var edges: [EdgeRow] = []
    @Published private(set) var edgeIsLoading = false
    @Published private(set) var edgeErrorMessage: String?

    @Published private(set) var oddsByGameId: [String: GameOdds] = [:]

    @Published private(set) var rankings: [RankingRow] = []
    @Published private(set) var rankingsIsLoading = false
    @Published private(set) var rankingsErrorMessage: String?

    private var pollTask: Task<Void, Never>?
    /// Matches web's LIVE_SCORE_POLL_MS (10 min) — no point refreshing
    /// faster than sync_live_scores itself updates.
    private static let livePollNanoseconds: UInt64 = 10 * 60 * 1_000_000_000

    var hasWeek: Bool { season != nil && week != nil }

    /// Used to resolve a Top Edges row's game_id back to team
    /// abbreviations for its label — mirrors BoardPage.jsx reusing the
    /// games list already fetched for the games strip instead of a
    /// second GET /teams call.
    var gamesById: [String: Game] {
        Dictionary(uniqueKeysWithValues: games.map { ($0.gameId, $0) })
    }

    var edgeByGameId: [String: EdgeRow] {
        Dictionary(uniqueKeysWithValues: edges.map { ($0.gameId, $0) })
    }

    /// Server already filtered to only_disagreements=true; Board further
    /// caps the preview list at 5, same as BoardPage.jsx's
    /// `edges.slice(0, TOP_EDGES_LIMIT)`.
    var topEdges: [EdgeRow] { Array(edges.prefix(5)) }

    private static let groupKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    private static let groupHeadingFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMd")
        formatter.timeZone = .current
        return formatter
    }()

    /// Buckets `games` by the viewer's own local calendar date — mirrors
    /// BoardPage.jsx's groupGamesByDate(), including its trailing
    /// "Date TBD" bucket for a game missing game_datetime.
    var gamesByDate: [BoardGameGroup] {
        var order: [String] = []
        var byKey: [String: (heading: String, games: [Game])] = [:]
        for game in games {
            let key: String
            let heading: String
            if let date = game.kickoffDate {
                key = Self.groupKeyFormatter.string(from: date)
                heading = Self.groupHeadingFormatter.string(from: date)
            } else {
                key = "zzzz-tbd"
                heading = "Date TBD"
            }
            if byKey[key] == nil {
                byKey[key] = (heading, [])
                order.append(key)
            }
            byKey[key]?.games.append(game)
        }
        return order.sorted().compactMap { key in
            guard let entry = byKey[key] else { return nil }
            return BoardGameGroup(id: key, heading: entry.heading, games: entry.games)
        }
    }

    func loadAll() async {
        await loadWeek()
        guard hasWeek else { return }
        async let gamesResult: () = loadGames()
        async let edgeResult: () = loadEdge()
        async let oddsResult: () = loadOdds()
        async let rankingsResult: () = loadRankings()
        _ = await (gamesResult, edgeResult, oddsResult, rankingsResult)
        updatePolling()
    }

    func loadWeek() async {
        weekIsLoading = true
        weekErrorMessage = nil
        do {
            let envelope: APIEnvelope<CurrentWeek> = try await APIClient.shared.get(Endpoints.gamesCurrentWeek)
            season = envelope.data.season
            week = envelope.data.week
        } catch let error as APIError {
            weekErrorMessage = error.errorDescription
        } catch {
            weekErrorMessage = error.localizedDescription
        }
        weekIsLoading = false
    }

    /// `silent` mirrors useApiFetch's `{ silent: true }` background poll
    /// — updates `games` in place without flipping the loading state,
    /// so a live scoreboard tick doesn't flash the page's spinner.
    func loadGames(silent: Bool = false) async {
        guard let season, let week else { return }
        if !silent {
            gamesIsLoading = true
            gamesErrorMessage = nil
        }
        do {
            let envelope: APIEnvelope<[Game]> = try await APIClient.shared.get(Endpoints.games(season: season, week: week))
            games = envelope.data
        } catch let error as APIError {
            if !silent { gamesErrorMessage = error.errorDescription }
        } catch {
            if !silent { gamesErrorMessage = error.localizedDescription }
        }
        if !silent { gamesIsLoading = false }
    }

    func loadEdge() async {
        guard let season, let week else { return }
        edgeIsLoading = true
        edgeErrorMessage = nil
        do {
            let envelope: APIEnvelope<[EdgeRow]> = try await APIClient.shared.get(
                Endpoints.edge(season: season, week: week, onlyDisagreements: true)
            )
            edges = envelope.data
        } catch let error as APIError {
            edgeErrorMessage = error.errorDescription
        } catch {
            edgeErrorMessage = error.localizedDescription
        }
        edgeIsLoading = false
    }

    func loadOdds() async {
        guard let season, let week else { return }
        do {
            let envelope: APIEnvelope<[GameOdds]> = try await APIClient.shared.get(Endpoints.odds(season: season, week: week))
            oddsByGameId = Dictionary(uniqueKeysWithValues: envelope.data.map { ($0.gameId, $0) })
        } catch {
            // Nice-to-have overlay, same as web — BoardPage.jsx never
            // surfaces an odds-specific error state. A failed fetch just
            // means no OddsBadge shows on any card this load.
        }
    }

    func loadRankings() async {
        guard let season, let week else { return }
        rankingsIsLoading = true
        rankingsErrorMessage = nil
        do {
            let envelope: APIEnvelope<[RankingRow]> = try await APIClient.shared.get(
                Endpoints.rankings(statCategory: "passing_yards", season: season, week: week, limit: 5)
            )
            rankings = envelope.data
        } catch let error as APIError {
            rankingsErrorMessage = error.errorDescription
        } catch {
            rankingsErrorMessage = error.localizedDescription
        }
        rankingsIsLoading = false
    }

    /// Background-polls this week's games silently while any of them is
    /// in_progress — mirrors BoardPage.jsx's
    /// `setLivePollMs(... ? LIVE_SCORE_POLL_MS : undefined)` + useApiFetch
    /// pairing.
    private func updatePolling() {
        pollTask?.cancel()
        guard games.contains(where: { $0.status == "in_progress" }) else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.livePollNanoseconds)
                guard !Task.isCancelled, let self else { return }
                await self.loadGames(silent: true)
                if !self.games.contains(where: { $0.status == "in_progress" }) {
                    return
                }
            }
        }
    }

    /// Called from BoardView's `.onDisappear` — cancels the live poll
    /// loop rather than letting it run forever in the background.
    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
