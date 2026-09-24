//
//  PlayersListView.swift
//  Chalk That NFL
//
//  Mirrors PlayerBrowsePage.jsx: debounced name search (via .searchable),
//  team + position group filters, "active in <season>" toggle on by
//  default.
//
import SwiftUI

struct PlayersListView: View {
    @StateObject private var viewModel = PlayersViewModel()

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            if viewModel.isLoading || viewModel.errorMessage != nil {
                AsyncStateView(
                    loading: viewModel.isLoading,
                    error: viewModel.errorMessage,
                    loadingLabel: "Loading players…",
                    onRetry: { Task { await viewModel.load() } }
                )
                Spacer()
            } else if viewModel.players.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Text("No players match this search.")
                        .font(.brandBody(14))
                        .foregroundStyle(Color.inkDim)
                    if viewModel.activeOnly {
                        Text("Try turning off \"Active only\" for a free agent or recently cut player.")
                            .font(.brandBody(12))
                            .foregroundStyle(Color.inkFaint)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
                Spacer()
            } else {
                List {
                    ForEach(viewModel.players) { player in
                        NavigationLink(value: ResearchRoute.playerDetail(player.playerId)) {
                            HStack {
                                Text(player.fullName)
                                    .font(.brandBody(14))
                                    .foregroundStyle(Color.ink)
                                Spacer()
                                Text([player.position as String?, player.teamAbbreviation].compactMap { $0 }.joined(separator: " · "))
                                    .font(.brandBody(12))
                                    .foregroundStyle(Color.inkFaint)
                                if player.status != "ACT" {
                                    Text(PlayerStatus.label(player.status))
                                        .font(.brandBody(11, weight: .semibold))
                                        .foregroundStyle(Color.inkDim)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.surface2)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                            }
                        }
                        .listRowBackground(Color.surface)
                    }
                    if viewModel.atResultsLimit {
                        Text("Showing the first 100 results — narrow your search to see more specific matches.")
                            .font(.brandBody(12))
                            .foregroundStyle(Color.inkFaint)
                            .listRowBackground(Color.canvas)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.canvas)
        .navigationTitle("Players")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.nameQuery, prompt: "Search by name")
        .task { await viewModel.loadTeamsForFilter() }
        .task { await viewModel.load() }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button("All teams") { viewModel.teamFilter = nil }
                ForEach(viewModel.teams) { team in
                    Button(team.name) { viewModel.teamFilter = team.abbreviation }
                }
            } label: {
                filterLabel(viewModel.teamFilter ?? "All teams")
            }

            Menu {
                Button("All positions") { viewModel.positionGroupFilter = nil }
                ForEach(PositionGroup.order, id: \.self) { group in
                    Button(PositionGroup.label[group] ?? group) { viewModel.positionGroupFilter = group }
                }
            } label: {
                filterLabel(viewModel.positionGroupFilter.flatMap { PositionGroup.label[$0] } ?? "All positions")
            }

            Spacer()

            Toggle("Active", isOn: $viewModel.activeOnly)
                .toggleStyle(.switch)
                .tint(Color.accent)
                .font(.brandBody(12))
                .foregroundStyle(Color.inkDim)
                .fixedSize()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.surface)
    }

    private func filterLabel(_ text: String) -> some View {
        Label(text, systemImage: "chevron.down")
            .font(.brandBody(13, weight: .medium))
            .foregroundStyle(Color.ink)
            .lineLimit(1)
    }
}
