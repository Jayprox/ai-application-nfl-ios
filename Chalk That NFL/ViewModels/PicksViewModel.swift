//
//  PicksViewModel.swift
//  Chalk That NFL
//
//  Mirrors PicksPage.jsx: one hardcoded agent scope (portfolio_agent_v1
//  — the only real writer to picks_log today, per that page's own
//  header comment), fetching /picks/stats and /picks for that agent in
//  parallel. No filters, no pagination controls — matches web's own
//  "everything this agent has logged" list exactly.
//
import Foundation
import Combine

@MainActor
final class PicksViewModel: ObservableObject {
    static let agentName = "portfolio_agent_v1"

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var stats: PicksStats?
    @Published private(set) var picks: [PickRow] = []

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
            async let statsEnvelope: APIEnvelope<PicksStats> = APIClient.shared.get(
                Endpoints.picksStats(agentName: Self.agentName)
            )
            async let picksResponse: PicksListResponse = APIClient.shared.get(
                Endpoints.picks(agentName: Self.agentName)
            )
            let (statsResult, listResult) = try await (statsEnvelope, picksResponse)
            stats = statsResult.data
            picks = listResult.data
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
