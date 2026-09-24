//
//  EdgeViewModel.swift
//  Chalk That NFL
//
//  Mirrors EdgePage.jsx: season/week/only-disagreements filters over
//  GET /edge, plus GET /teams (fetched once) to resolve home_team_id/
//  away_team_id to abbreviations for display — compareGameEdge()
//  returns raw team ids, not abbreviations (see EdgeModels.swift's own
//  header comment). Unlike Rankings/Props, week is REQUIRED here (same
//  as web: a blank week shows "Enter a week to see that week's games"
//  rather than fetching a whole-season view — /edge's own route 400s
//  without a week, there's no whole-season fallback like /rankings has).
//
import Foundation
import Combine

@MainActor
final class EdgeViewModel: ObservableObject {
    static let currentSeason = 2026
    static let lastSeason = 2025
    static let seasons = [currentSeason, lastSeason]

    @Published private(set) var season: Int = EdgeViewModel.currentSeason
    @Published var weekInput: String = "" {
        didSet {
            guard !isSeeding else { return }
            scheduleSearch()
        }
    }
    @Published var onlyDisagreements = false {
        didSet {
            guard !isSeeding else { return }
            Task { await load() }
        }
    }

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var edges: [EdgeRow] = []
    @Published private(set) var teams: [Int: String] = [:]
    @Published private(set) var hasResolvedCurrentWeek = false

    private var isSeeding = false
    private var searchTask: Task<Void, Never>?

    func loadInitial() async {
        async let teamsResult: () = loadTeams()
        async let weekResult: () = seedCurrentWeek()
        _ = await (teamsResult, weekResult)
    }

    private func loadTeams() async {
        guard teams.isEmpty else { return }
        if let envelope: APIEnvelope<[Team]> = try? await APIClient.shared.get(Endpoints.teams) {
            teams = Dictionary(uniqueKeysWithValues: envelope.data.map { ($0.teamId, $0.abbreviation) })
        }
    }

    private func seedCurrentWeek() async {
        guard !hasResolvedCurrentWeek else { return }
        isSeeding = true
        do {
            let envelope: APIEnvelope<CurrentWeek> = try await APIClient.shared.get(Endpoints.gamesCurrentWeek)
            season = envelope.data.season
            weekInput = String(envelope.data.week)
        } catch {
            // Not fatal — same "still usable by hand" fallback as the
            // other tabs' current-week seeds.
        }
        isSeeding = false
        hasResolvedCurrentWeek = true
        await load()
    }

    func setSeason(_ newValue: Int) async {
        season = newValue
        await load()
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    func load() async {
        let trimmedWeek = weekInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let week = Int(trimmedWeek) else {
            // Matches web's `!week` branch — no fetch attempted, the
            // View shows "Enter a week to see that week's games."
            edges = []
            errorMessage = nil
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let envelope: APIEnvelope<[EdgeRow]> = try await APIClient.shared.get(
                Endpoints.edge(season: season, week: week, onlyDisagreements: onlyDisagreements)
            )
            edges = envelope.data
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func abbreviation(for teamId: Int, fallback: String) -> String {
        teams[teamId] ?? fallback
    }
}
