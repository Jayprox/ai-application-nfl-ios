//
//  GamesViewModel.swift
//  Chalk That NFL
//
//  Mirrors GamesPage.jsx: seeds season/week from GET /games/current-week
//  on first load (so the screen never starts blank waiting for manual
//  input), then lets the person page through other weeks/seasons.
//  Edge/Odds overlays (GamesPage.jsx's edgePath/oddsPath) aren't wired
//  yet — those are the Rankings+Edge and Player Props+Odds build-order
//  phases, still ahead.
//
import Foundation
import Combine

@MainActor
final class GamesViewModel: ObservableObject {
    static let seasons = [2026, 2025, 2024, 2023, 2022, 2021] // matches GamesPage.jsx's SEASONS

    @Published var season = 2026
    @Published var week = 1
    @Published private(set) var games: [Game] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasResolvedCurrentWeek = false

    func loadInitial() async {
        guard !hasResolvedCurrentWeek else { return }
        do {
            let envelope: APIEnvelope<CurrentWeek> = try await APIClient.shared.get(Endpoints.gamesCurrentWeek)
            season = envelope.data.season
            week = envelope.data.week
        } catch {
            // Not fatal — the person can still pick a season/week by hand.
        }
        hasResolvedCurrentWeek = true
        await loadGames()
    }

    func loadGames() async {
        isLoading = true
        errorMessage = nil
        do {
            let envelope: APIEnvelope<[Game]> = try await APIClient.shared.get(Endpoints.games(season: season, week: week))
            games = envelope.data
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func goToPreviousWeek() async {
        week = max(1, week - 1)
        await loadGames()
    }

    func goToNextWeek() async {
        week = min(22, week + 1) // 18 regular-season weeks + postseason rounds
        await loadGames()
    }

    func setSeason(_ newSeason: Int) async {
        season = newSeason
        await loadGames()
    }
}
