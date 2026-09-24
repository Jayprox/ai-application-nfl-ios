//
//  PlayerDetailViewModel.swift
//  Chalk That NFL
//
//  load(playerId:) composes GET /players/:id (bio/injury -- gates the
//  screen) with GET /insights/players/:id (best-effort, via `try?` --
//  same "several independent fetches, one screen" shape as
//  GameDetailViewModel: a missing/failed insights read shouldn't block
//  the rest of the page, matching PlayerInsights.jsx's own "renders
//  nothing on error" convention).
//
//  fetchStats(...) is the separate POST /query fetch behind the stat
//  tabs (season/season_total/last5/career/game_log), called by
//  PlayerStatsSection whenever its scope/season/filter selection
//  changes. Mirrors useStatsQuery.js's stale-response protection: a
//  monotonically increasing generation counter, captured at the start
//  of each call, guards every write to @Published state at the end --
//  so if scope tabs are switched quickly and an older request's network
//  response lands after a newer one's, the older response is silently
//  discarded instead of overwriting the newer (correct) result. The
//  View additionally drives this via `.task(id:)`, whose built-in
//  cancellation stops the redundant network call in most cases -- the
//  generation counter is defense-in-depth for the same reason
//  useStatsQuery.js's own comment gives: don't trust "started first" to
//  mean "finishes first".
//
import Foundation
import Combine

@MainActor
final class PlayerDetailViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var player: PlayerDetail?
    @Published private(set) var insights: [PlayerInsightEntry] = []

    @Published private(set) var statsLoading = false
    @Published private(set) var statsErrorMessage: String?
    @Published private(set) var statEntries: [PlayerStatEntry] = []
    @Published private(set) var gameLogRows: [PlayerGameLogDisplayRow] = []
    @Published private(set) var statsSampleSize = 0
    @Published private(set) var statsSyncedAt: String?

    /// Matches PlayerDetailPage.jsx's AVAILABLE_SEASONS/DEFAULT_SEASON
    /// (the 2021-2025 historical backfill plus the live 2026 season) --
    /// same per-ViewModel `static let` convention EdgeViewModel/
    /// PortfolioViewModel/RankingsViewModel already use, rather than one
    /// shared global constant.
    static let currentSeason = 2026
    static let availableSeasons = [2026, 2025, 2024, 2023, 2022, 2021]

    private var statsRequestGeneration = 0

    func load(playerId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let envelope: APIEnvelope<PlayerDetail> = try await APIClient.shared.get(Endpoints.player(playerId))
            player = envelope.data
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false

        // PlayerInsights.jsx computes everything relative to this
        // player's *next scheduled game*, not whatever historical season
        // the stat tabs happen to be browsing -- so this always asks for
        // the live season, independent of PlayerStatsSection's own
        // `season` selection. See PlayerInsightModels.swift's header.
        if let envelope: APIEnvelope<PlayerInsightsData> = try? await APIClient.shared.get(
            Endpoints.playerInsights(playerId, season: Self.currentSeason)
        ) {
            insights = envelope.data.insights
        }
    }

    func fetchStats(
        playerId: String,
        positionGroup: String,
        scope: String,
        season: Int,
        homeAway: String?,
        gameSlot: String?,
        weatherCondition: String?
    ) async {
        statsRequestGeneration += 1
        let generation = statsRequestGeneration

        statsLoading = true
        statsErrorMessage = nil

        var splits: PlayerQuerySplitsBody?
        if homeAway != nil || gameSlot != nil || weatherCondition != nil {
            splits = PlayerQuerySplitsBody(homeAway: homeAway, gameSlot: gameSlot, weatherCondition: weatherCondition)
        }
        let body = PlayerQueryRequestBody(
            entityType: "player",
            entityId: playerId,
            scope: scope,
            season: scope == "career" ? nil : season,
            splits: splits
        )

        do {
            if scope == "game_log" {
                try await fetchGameLog(body: body, positionGroup: positionGroup, generation: generation)
            } else {
                try await fetchAggregate(body: body, positionGroup: positionGroup, generation: generation)
            }
        } catch let error as APIError {
            guard generation == statsRequestGeneration else { return }
            statsErrorMessage = error.errorDescription
            statsLoading = false
        } catch {
            guard generation == statsRequestGeneration else { return }
            statsErrorMessage = error.localizedDescription
            statsLoading = false
        }
    }

    private func fetchAggregate(body: PlayerQueryRequestBody, positionGroup: String, generation: Int) async throws {
        let entries: [PlayerStatEntry]
        let sampleSize: Int
        let syncedAt: String?

        switch positionGroup {
        case "defense":
            let envelope: PlayerQueryAggregateResponse<PlayerQueryDefenseAggregate> =
                try await APIClient.shared.post(Endpoints.query, body: body)
            entries = PlayerStatColumns.defense.map {
                PlayerStatEntry(id: $0.id, label: $0.label, displayValue: PlayerQueryDisplay.statGridValue(envelope.data.value(forKey: $0.id)))
            }
            sampleSize = envelope.meta.sampleSize
            syncedAt = envelope.meta.freshness?.syncedAt
        case "special_teams":
            let envelope: PlayerQueryAggregateResponse<PlayerQuerySpecialTeamsAggregate> =
                try await APIClient.shared.post(Endpoints.query, body: body)
            entries = PlayerStatColumns.specialTeams.map {
                PlayerStatEntry(id: $0.id, label: $0.label, displayValue: PlayerQueryDisplay.statGridValue(envelope.data.value(forKey: $0.id)))
            }
            sampleSize = envelope.meta.sampleSize
            syncedAt = envelope.meta.freshness?.syncedAt
        default:
            let envelope: PlayerQueryAggregateResponse<PlayerQueryOffenseAggregate> =
                try await APIClient.shared.post(Endpoints.query, body: body)
            entries = PlayerStatColumns.offense.map {
                PlayerStatEntry(id: $0.id, label: $0.label, displayValue: PlayerQueryDisplay.statGridValue(envelope.data.value(forKey: $0.id)))
            }
            sampleSize = envelope.meta.sampleSize
            syncedAt = envelope.meta.freshness?.syncedAt
        }

        guard generation == statsRequestGeneration else { return }
        statEntries = entries
        gameLogRows = []
        statsSampleSize = sampleSize
        statsSyncedAt = syncedAt
        statsLoading = false
    }

    private func fetchGameLog(body: PlayerQueryRequestBody, positionGroup: String, generation: Int) async throws {
        let rows: [PlayerGameLogDisplayRow]
        let sampleSize: Int
        let syncedAt: String?

        switch positionGroup {
        case "defense":
            let envelope: PlayerQueryGameLogResponse<PlayerQueryDefenseGameRow> =
                try await APIClient.shared.post(Endpoints.query, body: body)
            rows = envelope.data.map { PlayerGameLogDisplayRow(row: $0, columns: PlayerStatColumns.defense) }
            sampleSize = envelope.meta.sampleSize
            syncedAt = envelope.meta.freshness?.syncedAt
        case "special_teams":
            let envelope: PlayerQueryGameLogResponse<PlayerQuerySpecialTeamsGameRow> =
                try await APIClient.shared.post(Endpoints.query, body: body)
            rows = envelope.data.map { PlayerGameLogDisplayRow(row: $0, columns: PlayerStatColumns.specialTeams) }
            sampleSize = envelope.meta.sampleSize
            syncedAt = envelope.meta.freshness?.syncedAt
        default:
            let envelope: PlayerQueryGameLogResponse<PlayerQueryOffenseGameRow> =
                try await APIClient.shared.post(Endpoints.query, body: body)
            rows = envelope.data.map { PlayerGameLogDisplayRow(row: $0, columns: PlayerStatColumns.offense) }
            sampleSize = envelope.meta.sampleSize
            syncedAt = envelope.meta.freshness?.syncedAt
        }

        guard generation == statsRequestGeneration else { return }
        gameLogRows = rows
        statEntries = []
        statsSampleSize = sampleSize
        statsSyncedAt = syncedAt
        statsLoading = false
    }
}

// MARK: - Display-layer types (decoupled from which concrete Row type
// got decoded, same reason StatColumn<Row> keeps StatCategoryTable
// generic -- PlayerStatsSection only ever deals in these two types,
// never the six concrete wire-model Row structs directly).

struct PlayerStatEntry: Identifiable {
    let id: String
    let label: String
    let displayValue: String
}

struct PlayerGameLogCell: Identifiable {
    let id: String
    let label: String
    let value: String
}

struct PlayerGameLogDisplayRow: Identifiable {
    let id: String
    let week: Int
    let dateLabel: String
    let opponentLabel: String
    let cells: [PlayerGameLogCell]

    init(row: PlayerQueryGameRow, columns: [PlayerStatColumnDef]) {
        id = row.gameId
        week = row.week
        dateLabel = Self.formatDate(row.gameDatetime)
        opponentLabel = Self.formatOpponent(gameId: row.gameId, isHome: row.isHome)
        cells = columns.map { PlayerGameLogCell(id: $0.id, label: $0.label, value: row.rawDisplayValue(forKey: $0.id)) }
    }

    private static func formatDate(_ iso: String?) -> String {
        guard let date = BackendDate.parse(iso) else { return "—" }
        // Matches JS's `new Date(...).toLocaleDateString()` -- runtime's
        // default locale/format, not a hardcoded en-US pattern.
        return date.formatted(date: .numeric, time: .omitted)
    }

    /// game_id is SEASON_WEEK_AWAY_HOME (e.g. "2021_01_CHI_LA" --
    /// PlayerDetailPage.jsx's own opponentAbbr()) -- parsed directly
    /// from the id string, no extra request needed.
    private static func formatOpponent(gameId: String, isHome: Bool) -> String {
        let parts = gameId.split(separator: "_").map(String.init)
        guard parts.count >= 4 else { return isHome ? "vs ?" : "@ ?" }
        let away = parts[2]
        let home = parts[3]
        return (isHome ? "vs " : "@ ") + (isHome ? away : home)
    }
}
