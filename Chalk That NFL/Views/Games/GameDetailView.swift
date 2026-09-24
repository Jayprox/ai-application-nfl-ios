//
//  GameDetailView.swift
//  Chalk That NFL
//
//  Mirrors GameDetailPage.jsx's full section order: header → Model vs.
//  Market → Odds → Injuries → Player Stats → Live Box Score → Drive
//  Feed. Full parity phase (2026-09-21) — every section that page
//  renders now has an iOS counterpart; see HANDOFF.md for the
//  per-section decisions (lenient-decoding quirks, shared
//  StatCategoryTable, destination-based player links, etc.).
//
import SwiftUI

struct GameDetailView: View {
    let gameId: String
    @StateObject private var viewModel = GameDetailViewModel()

    var body: some View {
        ScrollView {
            if viewModel.isLoading || viewModel.errorMessage != nil {
                AsyncStateView(
                    loading: viewModel.isLoading,
                    error: viewModel.errorMessage,
                    loadingLabel: "Loading game…",
                    onRetry: { Task { await viewModel.load(gameId: gameId) } }
                )
            } else if let game = viewModel.game {
                VStack(alignment: .leading, spacing: 20) {
                    header(for: game)
                    edgeSection(for: game)
                    GameOddsSection(game: game, bookmakers: viewModel.odds)
                    if let injuries = viewModel.injuries {
                        injurySection(title: game.awayTeamAbbr, reports: injuries.away)
                        injurySection(title: game.homeTeamAbbr, reports: injuries.home)
                    }
                    GamePlayerStatsSection(
                        game: game,
                        sides: viewModel.playerStats,
                        sampleSize: viewModel.playerStatsSampleSize
                    )
                    GameBoxScoreSection(
                        game: game,
                        sides: viewModel.boxscore,
                        sampleSize: viewModel.boxscoreSampleSize,
                        syncedAt: viewModel.boxscoreSyncedAt
                    )
                    GameDriveFeedSection(
                        game: game,
                        drives: viewModel.drives,
                        syncedAt: viewModel.drivesSyncedAt
                    )
                }
                .padding()
            }
        }
        .background(Color.canvas)
        .navigationTitle(viewModel.game.map { "\($0.awayTeamAbbr) @ \($0.homeTeamAbbr)" } ?? "Game")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(gameId: gameId) }
    }

    private func header(for game: Game) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                teamColumn(name: game.awayTeamName, abbr: game.awayTeamAbbr, score: game.awayScore, show: game.status != "scheduled")
                Text("@")
                    .font(.brandBody(14))
                    .foregroundStyle(Color.inkFaint)
                teamColumn(name: game.homeTeamName, abbr: game.homeTeamAbbr, score: game.homeScore, show: game.status != "scheduled")
            }

            HStack(spacing: 8) {
                GameStatusBadge(status: game.status, period: game.gamePeriod, clock: game.gameClock)
                WeatherBadge(
                    condition: game.weatherCondition,
                    tempF: game.weatherTempF,
                    windMph: game.weatherWindMph,
                    windDirectionDeg: game.weatherWindDirectionDeg
                )
            }

            if let kickoff = game.kickoffDate {
                Text(kickoff.formatted(date: .abbreviated, time: .shortened))
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)
            }
            if let stadium = game.stadiumName {
                Text([stadium as String?, game.stadiumCity, game.stadiumState].compactMap { $0 }.joined(separator: ", "))
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func teamColumn(name: String, abbr: String, score: Int?, show: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(abbr)
                .font(.brandDisplay(20))
                .foregroundStyle(Color.ink)
            Text(name)
                .font(.brandBody(12))
                .foregroundStyle(Color.inkDim)
            if show, let score {
                Text(String(score))
                    .font(.brandBody(22, weight: .bold))
                    .foregroundStyle(Color.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func edgeSection(for game: Game) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model vs. Market")
                .font(.brandBody(13, weight: .semibold))
                .foregroundStyle(Color.inkFaint)
                .textCase(.uppercase)

            if let edge = viewModel.edge {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            edgeLine(label: "Model", favorite: edge.modelFavorite, margin: edge.modelMargin, source: nil, game: game)
                            edgeLine(label: "Market", favorite: edge.marketFavorite, margin: edge.marketMargin, source: edge.marketSource, game: game)
                        }
                        .font(.brandBody(13))
                        .foregroundStyle(Color.inkDim)

                        Spacer()

                        EdgeBadge(edge: edge.edge)
                    }
                    if !edge.note.isEmpty {
                        Text(edge.note)
                            .font(.brandBody(11))
                            .foregroundStyle(Color.inkFaint)
                    }
                }
                .padding(10)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Text("Edge read not available yet for this game.")
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)
            }
        }
    }

    private func edgeLine(label: String, favorite: String?, margin: Double?, source: String?, game: Game) -> some View {
        let abbr: String? = {
            switch favorite {
            case "home": return game.homeTeamAbbr
            case "away": return game.awayTeamAbbr
            default: return nil
            }
        }()
        return HStack(spacing: 3) {
            Text("\(label):")
            if let abbr {
                Text(abbr)
                    .font(.brandBody(13, weight: .medium))
                    .foregroundStyle(Color.ink)
            } else {
                Text("—")
            }
            if let margin {
                let marginText = String(format: "%.1f", margin)
                Text(source != nil ? "(\(source!), \(marginText))" : "(by \(marginText))")
            }
        }
    }

    private func injurySection(title: String, reports: [InjuryReport]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) Injuries")
                .font(.brandBody(13, weight: .semibold))
                .foregroundStyle(Color.inkFaint)
                .textCase(.uppercase)

            if reports.isEmpty {
                Text("No injuries reported.")
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)
            } else {
                VStack(spacing: 6) {
                    ForEach(reports) { report in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(report.fullName)
                                    .font(.brandBody(14, weight: .medium))
                                    .foregroundStyle(Color.ink)
                                Text(report.position)
                                    .font(.brandBody(12))
                                    .foregroundStyle(Color.inkFaint)
                            }
                            Spacer()
                            InjuryStatusBadge(
                                reportStatus: report.reportStatus,
                                primaryInjury: report.primaryInjury,
                                secondaryInjury: report.secondaryInjury
                            )
                        }
                        .padding(10)
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }
}
