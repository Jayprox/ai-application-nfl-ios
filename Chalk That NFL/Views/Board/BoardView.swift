//
//  BoardView.swift
//  Chalk That NFL
//
//  Mirrors BoardPage.jsx: the app's home tab — this week's games
//  (grouped by date), the edge agent's top 5 disagreements, and a
//  passing_yards rankings preview, each linking out to its own fuller
//  page once those exist (Games already does; Edge/Rankings full pages
//  are the Rankings+Edge phase, still ahead — see HANDOFF.md, so those
//  two section headers have no "view all" link yet).
//
//  Laid out with a plain ScrollView/VStack rather than List — Board
//  mixes a custom-grouped card grid with two very different list
//  styles (Top Edges, Rankings Leaders), which List's row/section model
//  doesn't fit as naturally as it did for Games/Teams/Players' flatter
//  browsable lists.
//
import SwiftUI

struct BoardView: View {
    @StateObject private var viewModel = BoardViewModel()

    var body: some View {
        ScrollView {
            content
                .padding()
        }
        .background(Color.canvas)
        .navigationTitle("Board")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { AccountMenuButton() }
        }
        .task { await viewModel.loadAll() }
        .onDisappear { viewModel.stopPolling() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.weekIsLoading || viewModel.weekErrorMessage != nil {
            AsyncStateView(
                loading: viewModel.weekIsLoading,
                error: viewModel.weekErrorMessage,
                loadingLabel: "Finding this week's games…",
                onRetry: { Task { await viewModel.loadAll() } }
            )
        } else if !viewModel.hasWeek {
            Text("No games in the schedule yet — once this week's slate is synced, Board will show it here along with top edges and rankings leaders.")
                .font(.brandBody(14))
                .foregroundStyle(Color.inkDim)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 24) {
                header
                gamesSection
                topEdgesSection
                rankingsSection
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let season = viewModel.season, let week = viewModel.week {
                Text("SEASON \(String(season)) · WEEK \(String(week))")
                    .font(.brandBody(11, weight: .semibold))
                    .foregroundStyle(Color.accent)
            }
            Text("This week's games, the edge agent's top disagreements, and this week's rankings leaders.")
                .font(.brandBody(13))
                .foregroundStyle(Color.inkDim)
        }
    }

    // MARK: - This Week's Games

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "This Week's Games", linkLabel: "Full schedule", route: .games)

            if viewModel.gamesIsLoading || viewModel.gamesErrorMessage != nil {
                AsyncStateView(
                    loading: viewModel.gamesIsLoading,
                    error: viewModel.gamesErrorMessage,
                    loadingLabel: "Loading games…",
                    onRetry: { Task { await viewModel.loadGames() } }
                )
            } else if viewModel.gamesByDate.isEmpty {
                Text("No games scheduled for week \(String(viewModel.week ?? 0)) yet.")
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.gamesByDate) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.heading)
                                .font(.brandBody(13, weight: .semibold))
                                .foregroundStyle(Color.inkDim)

                            VStack(spacing: 8) {
                                ForEach(group.games) { game in
                                    BoardGameCardView(
                                        game: game,
                                        edge: viewModel.edgeByGameId[game.gameId],
                                        odds: viewModel.oddsByGameId[game.gameId]
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Top Edges

    private var topEdgesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Top Edges", linkLabel: nil, route: nil)

            if viewModel.edgeIsLoading || viewModel.edgeErrorMessage != nil {
                AsyncStateView(
                    loading: viewModel.edgeIsLoading,
                    error: viewModel.edgeErrorMessage,
                    loadingLabel: "Loading edges…",
                    onRetry: { Task { await viewModel.loadEdge() } }
                )
            } else if viewModel.topEdges.isEmpty {
                Text("No model-vs-market disagreements found for this week.")
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)
            } else {
                VStack(spacing: 6) {
                    ForEach(viewModel.topEdges) { row in
                        NavigationLink(value: ResearchRoute.gameDetail(row.gameId)) {
                            HStack {
                                Text(matchupLabel(for: row))
                                    .font(.brandBody(14, weight: .medium))
                                    .foregroundStyle(Color.link)
                                Spacer()
                                EdgeBadge(edge: row.edge)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func matchupLabel(for row: EdgeRow) -> String {
        guard let game = viewModel.gamesById[row.gameId] else { return "Game \(row.gameId)" }
        return "\(game.awayTeamAbbr) @ \(game.homeTeamAbbr)"
    }

    // MARK: - Rankings Leaders

    private var rankingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Rankings Leaders", linkLabel: nil, route: nil)

            Text("Passing yards — top matchup scores this week.")
                .font(.brandBody(12))
                .foregroundStyle(Color.inkDim)

            if viewModel.rankingsIsLoading || viewModel.rankingsErrorMessage != nil {
                AsyncStateView(
                    loading: viewModel.rankingsIsLoading,
                    error: viewModel.rankingsErrorMessage,
                    loadingLabel: "Loading rankings…",
                    onRetry: { Task { await viewModel.loadRankings() } }
                )
            } else if viewModel.rankings.isEmpty {
                Text("No rankings computed yet for this week.")
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)
            } else {
                VStack(spacing: 4) {
                    ForEach(viewModel.rankings) { row in
                        NavigationLink(value: ResearchRoute.playerDetail(row.playerId)) {
                            HStack(spacing: 8) {
                                Text(String(row.rank))
                                    .font(.brandBody(13, weight: .semibold))
                                    .foregroundStyle(Color.inkFaint)
                                    .frame(width: 20, alignment: .leading)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(row.playerName)
                                        .font(.brandBody(14))
                                        .foregroundStyle(Color.ink)
                                    Text(row.position)
                                        .font(.brandBody(11))
                                        .foregroundStyle(Color.inkFaint)
                                }
                                Spacer()
                                Text(String(format: "%.1f", row.score))
                                    .font(.brandBody(13))
                                    .foregroundStyle(Color.inkDim)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Shared

    @ViewBuilder
    private func sectionHeader(title: String, linkLabel: String?, route: ResearchRoute?) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.brandBody(11, weight: .semibold))
                .foregroundStyle(Color.inkFaint)
            Spacer()
            if let linkLabel, let route {
                NavigationLink(value: route) {
                    Text("\(linkLabel) →")
                        .font(.brandBody(11))
                        .foregroundStyle(Color.link)
                }
            }
        }
    }
}
