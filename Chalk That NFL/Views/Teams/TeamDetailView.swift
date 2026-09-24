//
//  TeamDetailView.swift
//  Chalk That NFL
//
//  Mirrors TeamDetailPage.jsx: team header + roster grouped depth-chart
//  style. The "Resync rosters" admin action on web is deliberately not
//  reproduced here — admin sync triggers are out of scope for this app
//  (confirmed with JD 2026-09-19, see HANDOFF.md).
//
import SwiftUI

private enum RosterRow: Identifiable {
    case header(String, Int)
    case player(RosterPlayer)

    var id: String {
        switch self {
        case .header(let label, _): return "header::\(label)"
        case .player(let player): return "player::\(player.playerId)"
        }
    }
}

private func flattenedRoster(_ groups: [KeyedGroup<RosterPlayer>]) -> [RosterRow] {
    groups.flatMap { group -> [RosterRow] in
        let label = "\(RosterPositions.label[group.id] ?? group.id) (\(group.items.count))"
        return [RosterRow.header(label, group.items.count)] + group.items.map(RosterRow.player)
    }
}

struct TeamDetailView: View {
    let teamId: Int
    @StateObject private var viewModel = TeamDetailViewModel()

    var body: some View {
        // Keep a concrete container mounted even before load() begins.
        // An empty Group has no child to run its .task or apply its title to.
        VStack(spacing: 0) {
            if viewModel.isLoading || viewModel.errorMessage != nil {
                AsyncStateView(
                    loading: viewModel.isLoading,
                    error: viewModel.errorMessage,
                    loadingLabel: "Loading team…",
                    onRetry: { Task { await viewModel.load(teamId: teamId) } }
                )
            } else if let team = viewModel.team {
                List {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(team.name)
                            .font(.brandDisplay(22))
                            .foregroundStyle(Color.ink)
                        Text(teamSubtitle(team))
                            .font(.brandBody(13))
                            .foregroundStyle(Color.inkDim)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.canvas)

                    if viewModel.rosterByPosition.isEmpty {
                        Text("No roster on file for this team.")
                            .font(.brandBody(13))
                            .foregroundStyle(Color.inkDim)
                            .listRowBackground(Color.canvas)
                    }

                    ForEach(flattenedRoster(viewModel.rosterByPosition)) { row in
                        switch row {
                        case .header(let label, _):
                            Text(label)
                                .font(.brandBody(12, weight: .semibold))
                                .foregroundStyle(Color.inkFaint)
                                .listRowBackground(Color.canvas)
                                .listRowSeparator(.hidden)
                                .padding(.top, 6)
                        case .player(let player):
                            NavigationLink(value: ResearchRoute.playerDetail(player.playerId)) {
                                HStack {
                                    Text(player.fullName)
                                        .font(.brandBody(14))
                                        .foregroundStyle(Color.ink)
                                    Spacer()
                                    Text(player.position)
                                        .font(.brandBody(12))
                                        .foregroundStyle(Color.inkFaint)
                                    if player.status == "RES" {
                                        Text("IR")
                                            .font(.brandBody(11, weight: .semibold))
                                            .foregroundStyle(Color.caution)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.caution.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    }
                                }
                            }
                            .listRowBackground(Color.surface)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.canvas)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.canvas)
        .navigationTitle(viewModel.team?.abbreviation ?? "Team")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(teamId: teamId) }
    }

    private func teamSubtitle(_ team: TeamDetail) -> String {
        var parts = ["\(team.conference) \(team.division)"]
        if let stadium = team.stadiumName, let city = team.city, let state = team.state {
            var stadiumLine = "\(stadium), \(city), \(state)"
            if let roof = team.roof, roof != "outdoors" { stadiumLine += " (\(roof))" }
            parts.append(stadiumLine)
        }
        return parts.joined(separator: " · ")
    }
}
