//
//  TeamDetailViewModel.swift
//  Chalk That NFL
//
import Foundation
import Combine

@MainActor
final class TeamDetailViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var team: TeamDetail?

    /// [(bucket key, players)] in RosterPositions.order, with any
    /// unrecognized raw position code appended alphabetically at the end
    /// rather than dropped — mirrors TeamDetailPage.jsx exactly.
    var rosterByPosition: [KeyedGroup<RosterPlayer>] {
        guard let roster = team?.roster else { return [] }
        let grouped = Dictionary(grouping: roster) { RosterPositions.bucket(for: $0.position) }
        let leftover = grouped.keys.filter { !RosterPositions.order.contains($0) }.sorted()
        let orderedBuckets = RosterPositions.order + leftover
        return orderedBuckets.compactMap { bucket in
            guard let players = grouped[bucket], !players.isEmpty else { return nil }
            return KeyedGroup(id: bucket, items: players)
        }
    }

    func load(teamId: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            let envelope: APIEnvelope<TeamDetail> = try await APIClient.shared.get(Endpoints.team(teamId))
            team = envelope.data
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
