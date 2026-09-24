//
//  GamesListView.swift
//  Chalk That NFL
//
//  Mirrors GamesPage.jsx: seeds season/week from GET /games/current-week,
//  lets the person page week-to-week or change season. Pushed onto
//  Research's shared NavigationStack (see ResearchRoute.swift) — does
//  not declare its own NavigationStack.
//
import SwiftUI

struct GamesListView: View {
    @StateObject private var viewModel = GamesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            weekControls

            if viewModel.isLoading || viewModel.errorMessage != nil {
                AsyncStateView(
                    loading: viewModel.isLoading,
                    error: viewModel.errorMessage,
                    loadingLabel: "Loading games…",
                    onRetry: { Task { await viewModel.loadGames() } }
                )
                Spacer()
            } else if viewModel.games.isEmpty {
                Spacer()
                Text("No games scheduled for this week.")
                    .font(.brandBody(14))
                    .foregroundStyle(Color.inkDim)
                Spacer()
            } else {
                List(viewModel.games) { game in
                    NavigationLink(value: ResearchRoute.gameDetail(game.gameId)) {
                        GameRowView(game: game)
                    }
                    .listRowBackground(Color.surface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.canvas)
        .navigationTitle("Games")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadInitial() }
    }

    private var weekControls: some View {
        HStack {
            Menu {
                ForEach(GamesViewModel.seasons, id: \.self) { season in
                    Button(String(season)) { Task { await viewModel.setSeason(season) } }
                }
            } label: {
                Label(String(viewModel.season), systemImage: "chevron.down")
                    .font(.brandBody(14, weight: .medium))
            }

            Spacer()

            HStack(spacing: 16) {
                Button { Task { await viewModel.goToPreviousWeek() } } label: {
                    Image(systemName: "chevron.left")
                }
                Text("Week \(String(viewModel.week))")
                    .font(.brandBody(14, weight: .semibold))
                    .frame(minWidth: 70)
                Button { Task { await viewModel.goToNextWeek() } } label: {
                    Image(systemName: "chevron.right")
                }
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.surface)
    }
}
