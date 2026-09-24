//
//  RankingsViewModel.swift
//  Chalk That NFL
//
//  Mirrors RankingsPage.jsx: seeds season/week from GET /games/
//  current-week (same as GamesViewModel/PropsViewModel), then lets the
//  person change stat category, season, or clear the week field
//  (blank = whole-season top N, same as web's optional week input) —
//  each of those re-fetches GET /rankings.
//
//  Season/stat-category changes go through explicit action methods
//  (setSeason/setStatCategory), same "mutate then immediately reload"
//  shape GamesViewModel's setSeason already uses — avoids the double-
//  fetch a reactive `didSet` would cause when this same property is
//  ALSO being set programmatically during the initial current-week
//  seed. The free-text week field, by contrast, genuinely needs a
//  debounce (same reasoning as PlayersViewModel's nameQuery) since it's
//  raw keyboard input, not a discrete picker action — an `isSeeding`
//  guard suppresses that debounce specifically during the initial seed,
//  so `loadInitial()`'s own explicit `load()` call is the only fetch
//  that happens on first launch.
//
import Foundation
import Combine

@MainActor
final class RankingsViewModel: ObservableObject {
    static let currentSeason = 2026
    static let lastSeason = 2025
    static let seasons = [currentSeason, lastSeason]

    @Published private(set) var statCategory: RankingStatCategory = .passingYards
    @Published private(set) var season: Int = RankingsViewModel.currentSeason
    @Published var weekInput: String = "" {
        didSet {
            guard !isSeeding else { return }
            scheduleSearch()
        }
    }

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var rankings: [RankingRow] = []
    @Published private(set) var count: Int = 0
    @Published private(set) var freshnessSyncedAt: String?
    @Published private(set) var hasResolvedCurrentWeek = false

    private var isSeeding = false
    private var searchTask: Task<Void, Never>?

    func loadInitial() async {
        guard !hasResolvedCurrentWeek else { return }
        isSeeding = true
        do {
            let envelope: APIEnvelope<CurrentWeek> = try await APIClient.shared.get(Endpoints.gamesCurrentWeek)
            season = envelope.data.season
            weekInput = String(envelope.data.week)
        } catch {
            // Not fatal — same "still usable by hand" fallback as
            // GamesViewModel/PropsViewModel's own current-week seed.
        }
        isSeeding = false
        hasResolvedCurrentWeek = true
        await load()
    }

    func setStatCategory(_ newValue: RankingStatCategory) async {
        statCategory = newValue
        await load()
    }

    func setSeason(_ newValue: Int) async {
        season = newValue
        await load()
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // matches web's PlayersViewModel-style debounce
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let trimmedWeek = weekInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let week = trimmedWeek.isEmpty ? nil : Int(trimmedWeek)
            let response: RankingsResponse = try await APIClient.shared.get(
                Endpoints.rankings(statCategory: statCategory.rawValue, season: season, week: week, limit: 20)
            )
            rankings = response.data
            count = response.meta.count
            freshnessSyncedAt = response.meta.freshness.syncedAt
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
