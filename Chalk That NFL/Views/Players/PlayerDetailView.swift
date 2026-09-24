//
//  PlayerDetailView.swift
//  Chalk That NFL
//
//  Mirrors PlayerDetailPage.jsx's identity/bio header plus (2026-09-22,
//  "match the web version" full-parity phase) its insights card and
//  stat tabs -- see PlayerStatsSection.swift for the scope tabs/
//  filters/StatGrid/GameLogTable and PlayerInsightModels.swift /
//  PlayerQueryModels.swift for the wire models behind them.
//
import SwiftUI

struct PlayerDetailView: View {
    let playerId: String
    @StateObject private var viewModel = PlayerDetailViewModel()

    var body: some View {
        ScrollView {
            if viewModel.isLoading || viewModel.errorMessage != nil {
                AsyncStateView(
                    loading: viewModel.isLoading,
                    error: viewModel.errorMessage,
                    loadingLabel: "Loading player…",
                    onRetry: { Task { await viewModel.load(playerId: playerId) } }
                )
            } else if let player = viewModel.player {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(player.fullName)
                            .font(.brandDisplay(24))
                            .foregroundStyle(Color.ink)

                        HStack(spacing: 8) {
                            Text([player.position as String?, player.teamName].compactMap { $0 }.joined(separator: " · "))
                                .font(.brandBody(14))
                                .foregroundStyle(Color.inkDim)

                            if player.status != "ACT" {
                                let label = PlayerStatus.label(player.status)
                                if !label.isEmpty {
                                    Text(label)
                                        .font(.brandBody(11, weight: .semibold))
                                        .foregroundStyle(Color.inkDim)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.surface2)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                            }
                        }

                        if let injury = player.currentInjury {
                            InjuryStatusBadge(
                                reportStatus: injury.reportStatus,
                                primaryInjury: injury.primaryInjury,
                                secondaryInjury: injury.secondaryInjury
                            )
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if let draftYear = player.draftYear {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DRAFT")
                                .font(.brandBody(11, weight: .semibold))
                                .foregroundStyle(Color.inkFaint)
                            Text(draftDescription(year: draftYear, round: player.draftRound, pick: player.draftPick))
                                .font(.brandBody(14))
                                .foregroundStyle(Color.ink)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    PlayerInsightsSection(insights: viewModel.insights)

                    PlayerStatsSection(player: player, viewModel: viewModel)
                }
                .padding()
            }
        }
        .background(Color.canvas)
        .navigationTitle(viewModel.player?.fullName ?? "Player")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(playerId: playerId) }
    }

    private func draftDescription(year: Int, round: Int?, pick: Int?) -> String {
        if let round, let pick {
            return "\(year) · Round \(round), Pick \(pick)"
        }
        return "\(year)"
    }
}
