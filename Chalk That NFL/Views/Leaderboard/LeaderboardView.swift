//
//  LeaderboardView.swift
//  Chalk That NFL
//
//  Mirrors LeaderboardPage.jsx: every agent logging picks, ranked by
//  hit rate. Web renders this as a wide HTML table (#, Agent, Record,
//  Hit Rate, Pending, Total); on a phone width that reads better as a
//  row list — rank + agent name + hit rate up front (the sort key,
//  same visual priority web gives it via column order) with record/
//  pending/total folded into a caption line, same "row card" shape
//  RankingRowView/EdgeRowView already use elsewhere in this tab group
//  rather than a horizontally-scrolling table, which isn't an iOS
//  reading pattern. Pushed onto Record's shared NavigationStack (see
//  RecordRoute.swift).
//
import SwiftUI

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Text("Every agent logging picks, ranked by hit rate. More rows appear as more agents start picking.")
                .font(.brandBody(13))
                .foregroundStyle(Color.inkDim)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surface)

            if viewModel.isLoading || viewModel.errorMessage != nil {
                AsyncStateView(
                    loading: viewModel.isLoading,
                    error: viewModel.errorMessage,
                    loadingLabel: "Loading leaderboard\u{2026}",
                    onRetry: { Task { await viewModel.refresh() } }
                )
                Spacer()
            } else if viewModel.agents.isEmpty {
                Spacer()
                Text("No picks logged by any agent yet.")
                    .font(.brandBody(14))
                    .foregroundStyle(Color.inkDim)
                Spacer()
            } else {
                List {
                    ForEach(viewModel.agents) { agent in
                        LeaderboardRowView(agent: agent)
                            .listRowBackground(Color.surface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.canvas)
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadIfNeeded() }
    }
}

private struct LeaderboardRowView: View {
    let agent: LeaderboardEntry

    private var recordText: String {
        var text = "\(agent.correct)-\(agent.incorrect)"
        if agent.push > 0 { text += "-\(agent.push)" }
        return text
    }

    private var hitRateText: String {
        agent.hitRatePct.map { "\(PortfolioFormat.number($0))%" } ?? "\u{2014}"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(agent.rank))
                .font(.brandBody(15, weight: .bold))
                .foregroundStyle(Color.inkFaint)
                .frame(width: 22, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.agentName)
                    .font(.brandBody(14, weight: .medium))
                    .foregroundStyle(Color.ink)
                Text("Record \(recordText) \u{b7} Pending \(agent.pending) \u{b7} Total \(agent.total)")
                    .font(.brandBody(11))
                    .foregroundStyle(Color.inkFaint)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(hitRateText)
                    .font(.brandBody(16, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Text("Hit rate")
                    .font(.brandBody(10))
                    .foregroundStyle(Color.inkFaint)
            }
        }
        .padding(.vertical, 4)
    }
}
