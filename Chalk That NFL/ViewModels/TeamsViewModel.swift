//
//  TeamsViewModel.swift
//  Chalk That NFL
//
import Foundation
import Combine

@MainActor
final class TeamsViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var teamsByDivision: [KeyedGroup<Team>] = []

    private static let divisionOrder = [
        "AFC East", "AFC North", "AFC South", "AFC West",
        "NFC East", "NFC North", "NFC South", "NFC West",
    ]

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let envelope: APIEnvelope<[Team]> = try await APIClient.shared.get(Endpoints.teams)
            let grouped = Dictionary(grouping: envelope.data) { "\($0.conference) \($0.division)" }
            teamsByDivision = Self.divisionOrder.compactMap { division in
                guard let teams = grouped[division], !teams.isEmpty else { return nil }
                return KeyedGroup(id: division, items: teams.sorted { $0.name < $1.name })
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
