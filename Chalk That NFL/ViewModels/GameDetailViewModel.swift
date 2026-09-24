//
//  GameDetailViewModel.swift
//  Chalk That NFL
//
//  Composes GET /games/:id with GET /games/:id/injuries — same "several
//  independent fetches, one screen" shape as GameDetailPage.jsx. Those
//  two gate the screen (a failure there shows AsyncStateView's error
//  state); everything else — edge, odds, boxscore, player-stats, drives
//  — is a THIRD-and-on, independent, best-effort read via `try?`, same
//  as web's own separate useApiFetch() calls for each: a missing/failed
//  read there should never block the rest of the screen, just fall back
//  to that section's own empty state.
//
//  Boxscore and drives don't poll while the game is live (unlike web's
//  own livePollMs reuse for those two) — GameDetailView has no existing
//  polling infrastructure to hook into yet, and JD didn't ask for it;
//  flagged in HANDOFF.md as a deliberate, scoped-down gap rather than a
//  missed requirement, not something to add unprompted.
//
import Foundation
import Combine

@MainActor
final class GameDetailViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var game: Game?
    @Published private(set) var injuries: GameInjuries?
    @Published private(set) var edge: EdgeRow?
    @Published private(set) var odds: [BookmakerLine] = []
    @Published private(set) var boxscore: BoxScoreSides?
    @Published private(set) var boxscoreSampleSize = 0
    @Published private(set) var boxscoreSyncedAt: String?
    @Published private(set) var playerStats: PlayerSeasonSides?
    @Published private(set) var playerStatsSampleSize = 0
    @Published private(set) var drives: [GameDrive] = []
    @Published private(set) var drivesSyncedAt: String?

    func load(gameId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            async let gameEnvelope: APIEnvelope<Game> = APIClient.shared.get(Endpoints.game(gameId))
            async let injuriesEnvelope: APIEnvelope<GameInjuries> = APIClient.shared.get(Endpoints.gameInjuries(gameId))
            let (gameResult, injuriesResult) = try await (gameEnvelope, injuriesEnvelope)
            game = gameResult.data
            injuries = injuriesResult.data
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false

        if let envelope: APIEnvelope<EdgeRow> = try? await APIClient.shared.get(Endpoints.gameEdge(gameId)) {
            edge = envelope.data
        }

        if let envelope: APIEnvelope<GameOdds> = try? await APIClient.shared.get(Endpoints.gameOdds(gameId)) {
            odds = envelope.data.bookmakers
        }

        if let envelope: BoxScoreResponse = try? await APIClient.shared.get(Endpoints.gameBoxscore(gameId)) {
            boxscore = envelope.data
            boxscoreSampleSize = envelope.meta.sampleSize ?? 0
            boxscoreSyncedAt = envelope.meta.freshness?.syncedAt
        }

        if let envelope: PlayerSeasonStatsResponse = try? await APIClient.shared.get(Endpoints.gamePlayerStats(gameId)) {
            playerStats = envelope.data
            playerStatsSampleSize = envelope.meta.sampleSize
        }

        if let envelope: DriveFeedResponse = try? await APIClient.shared.get(Endpoints.gameDrives(gameId)) {
            drives = envelope.data ?? []
            drivesSyncedAt = envelope.meta.freshness?.syncedAt
        }
    }
}
