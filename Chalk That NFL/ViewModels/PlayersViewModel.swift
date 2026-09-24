//
//  PlayersViewModel.swift
//  Chalk That NFL
//
//  Mirrors PlayerBrowsePage.jsx: debounced name search, team + position
//  group filters, "active in <season>" checkbox on by default.
//
import Foundation
import Combine

@MainActor
final class PlayersViewModel: ObservableObject {
    @Published var nameQuery = "" {
        didSet { scheduleSearch() }
    }
    @Published var teamFilter: String? {
        didSet { Task { await load() } }
    }
    @Published var positionGroupFilter: String? {
        didSet { Task { await load() } }
    }
    @Published var activeOnly = true {
        didSet { Task { await load() } }
    }

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var players: [PlayerSummary] = []
    @Published private(set) var atResultsLimit = false
    @Published private(set) var teams: [Team] = []

    private var searchTask: Task<Void, Never>?
    private var debouncedName = ""

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // matches web's 300ms debounce
            guard !Task.isCancelled else { return }
            debouncedName = nameQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            await load()
        }
    }

    func loadTeamsForFilter() async {
        guard teams.isEmpty else { return }
        if let envelope: APIEnvelope<[Team]> = try? await APIClient.shared.get(Endpoints.teams) {
            teams = envelope.data.sorted { $0.name < $1.name }
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let path = Endpoints.players(
                name: debouncedName.isEmpty ? nil : debouncedName,
                team: teamFilter,
                positionGroup: positionGroupFilter,
                activeOnly: activeOnly
            )
            let envelope: APIEnvelope<[PlayerSummary]> = try await APIClient.shared.get(path)
            players = envelope.data
            atResultsLimit = envelope.data.count == 100 // MAX_RESULTS in backend/routes/players.js
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
