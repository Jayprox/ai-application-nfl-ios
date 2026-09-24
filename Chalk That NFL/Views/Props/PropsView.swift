//
//  PropsView.swift
//  Chalk That NFL
//
//  Mirrors PropsPage.jsx: a row of market tabs (this app's 5 launch
//  markets) over a per-game grouped list of prop cards, ranked within
//  each game by how far recent form clears the line (strongest reads
//  first) — never a simulation/confidence-score treatment, see
//  PropModels.swift's own header comment. Pushed onto Agents' shared
//  NavigationStack (see AgentsRoute.swift) — does not declare its own
//  NavigationStack, same convention GamesListView/PlayersListView use
//  under Research.
//
import SwiftUI

struct PropsView: View {
    @StateObject private var viewModel = PropsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            marketTabs

            if viewModel.isLoading || viewModel.errorMessage != nil {
                AsyncStateView(
                    loading: viewModel.isLoading,
                    error: viewModel.errorMessage,
                    loadingLabel: "Loading props…",
                    onRetry: { Task { await viewModel.refresh() } }
                )
                Spacer()
            } else if viewModel.groupedByGame.isEmpty {
                Spacer()
                Text("No \(viewModel.activeMarket.label.lowercased()) props synced yet this week.")
                    .font(.brandBody(14))
                    .foregroundStyle(Color.inkDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(viewModel.groupedByGame) { group in
                            PropGameGroupSection(group: group)
                        }

                        if viewModel.sampleSize > 0 {
                            Text("\(String(viewModel.sampleSize)) prop\(viewModel.sampleSize == 1 ? "" : "s") across all markets · \(RelativeTime.sinceSynced(viewModel.freshnessSyncedAt))")
                                .font(.brandBody(11))
                                .foregroundStyle(Color.inkFaint)
                                .padding(.top, 4)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color.canvas)
        .navigationTitle("Props")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadIfNeeded() }
    }

    private var marketTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PropMarket.allCases) { market in
                    Button {
                        viewModel.activeMarket = market
                    } label: {
                        Text(market.label)
                            .font(.brandBody(13, weight: .medium))
                            .foregroundStyle(viewModel.activeMarket == market ? Color.onAccent : Color.inkDim)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(viewModel.activeMarket == market ? Color.accent : Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.surface)
    }
}

private struct PropGameGroupSection: View {
    let group: PropGameGroup

    private var kickoffLabel: String? {
        guard let date = group.game?.kickoffDate else { return nil }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE, h:mm a")
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let game = group.game {
                    NavigationLink(value: AgentsRoute.gameDetail(group.gameId)) {
                        Text("\(game.awayTeamAbbr) @ \(game.homeTeamAbbr)")
                            .font(.brandBody(14, weight: .semibold))
                            .foregroundStyle(Color.ink)
                    }
                } else {
                    Text(group.gameId)
                        .font(.brandBody(14, weight: .semibold))
                        .foregroundStyle(Color.ink)
                }
                Spacer()
                if let kickoffLabel {
                    Text(kickoffLabel)
                        .font(.brandBody(11))
                        .foregroundStyle(Color.inkFaint)
                }
            }

            VStack(spacing: 8) {
                ForEach(group.rows) { prop in
                    PropCardView(prop: prop)
                }
            }
        }
    }
}
