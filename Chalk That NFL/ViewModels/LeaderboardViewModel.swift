//
//  LeaderboardViewModel.swift
//  Chalk That NFL
//
//  Mirrors LeaderboardPage.jsx: a single unfiltered GET /leaderboard
//  fetch, no params, no controls.
//
import Foundation
import Combine

@MainActor
final class LeaderboardViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var agents: [LeaderboardEntry] = []

    private var hasLoaded = false

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await load()
    }

    func refresh() async {
        await load()
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: LeaderboardResponse = try await APIClient.shared.get(Endpoints.leaderboard)
            agents = response.data
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
