//
//  PortfolioViewModel.swift
//  Chalk That NFL
//
//  Mirrors PortfolioPage.jsx: season/week/max-picks/unit-size inputs
//  feeding POST /portfolio/slate, with two distinct actions — Preview
//  (dry_run=true, no write) and Build & log (dry_run=false, real write
//  to picks_log) — rather than one action gated by a checkbox, same
//  "two distinct actions read better than one + a toggle" reasoning as
//  web's own two-button layout.
//
//  Season/week seed from GET /games/current-week exactly like Edge/
//  Rankings/Props (seedCurrentWeek only ever runs once — hence
//  hasResolvedCurrentWeek — since after that point week is under the
//  person's own control, same as web's useCurrentWeek hook only firing
//  once on mount). maxPicksInput/unitSizeInput are plain optional text
//  fields with no debounce and no auto-refetch — unlike Rankings/Edge's
//  weekInput, nothing here re-fetches as you type; a slate is only ever
//  built by an explicit tap on one of the two buttons, matching web's
//  own request-on-click (not request-on-change) design.
//
import Foundation
import Combine

@MainActor
final class PortfolioViewModel: ObservableObject {
    static let currentSeason = 2026
    static let lastSeason = 2025
    static let seasons = [currentSeason, lastSeason]

    enum Mode {
        case preview, build
    }

    @Published private(set) var season: Int = PortfolioViewModel.currentSeason
    @Published var weekInput: String = ""
    @Published var maxPicksInput: String = "5"
    @Published var unitSizeInput: String = "1"

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var result: PortfolioSlateResult?
    @Published private(set) var mode: Mode?
    @Published private(set) var teams: [Int: String] = [:]

    private var hasResolvedCurrentWeek = false

    var trimmedWeek: String { weekInput.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canRun: Bool { !trimmedWeek.isEmpty && !isLoading }

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
        do {
            let envelope: APIEnvelope<CurrentWeek> = try await APIClient.shared.get(Endpoints.gamesCurrentWeek)
            season = envelope.data.season
            weekInput = String(envelope.data.week)
        } catch {
            // Not fatal — same "still usable by hand" fallback as the
            // other tabs' current-week seeds.
        }
        hasResolvedCurrentWeek = true
    }

    func setSeason(_ newValue: Int) {
        season = newValue
    }

    func abbreviation(for teamId: Int, fallback: String) -> String {
        teams[teamId] ?? fallback
    }

    func run(dryRun: Bool) async {
        guard canRun, let week = Int(trimmedWeek) else { return }
        isLoading = true
        errorMessage = nil
        let trimmedMaxPicks = maxPicksInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnitSize = unitSizeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxPicks = trimmedMaxPicks.isEmpty ? nil : Int(trimmedMaxPicks)
        let unitSize = trimmedUnitSize.isEmpty ? nil : Double(trimmedUnitSize)
        do {
            let envelope: APIEnvelope<PortfolioSlateResult> = try await APIClient.shared.post(
                Endpoints.portfolioSlate(season: season, week: week, maxPicks: maxPicks, unitSize: unitSize, dryRun: dryRun)
            )
            result = envelope.data
            mode = dryRun ? .preview : .build
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
