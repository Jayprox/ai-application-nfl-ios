//
//  RankingsView.swift
//  Chalk That NFL
//
//  Mirrors RankingsPage.jsx: a stat-category/season/week filter bar over
//  a ranked list of matchup scores — a deterministic trend score (no
//  market data, no LLM call), not a production forecast. Pushed onto
//  Agents' shared NavigationStack (see AgentsRoute.swift).
//
import SwiftUI

struct RankingsView: View {
    @StateObject private var viewModel = RankingsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            if viewModel.isLoading || viewModel.errorMessage != nil {
                AsyncStateView(
                    loading: viewModel.isLoading,
                    error: viewModel.errorMessage,
                    loadingLabel: "Loading rankings…",
                    onRetry: { Task { await viewModel.load() } }
                )
                Spacer()
            } else if viewModel.rankings.isEmpty {
                Spacer()
                Text(emptyStateMessage)
                    .font(.brandBody(14))
                    .foregroundStyle(Color.inkDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            } else {
                List {
                    ForEach(viewModel.rankings) { row in
                        RankingRowView(row: row, unit: viewModel.statCategory.unit)
                            .listRowBackground(Color.surface)
                    }
                    if viewModel.count > 0 {
                        Text("\(String(viewModel.count)) player\(viewModel.count == 1 ? "" : "s") · \(RelativeTime.sinceComputed(viewModel.freshnessSyncedAt))")
                            .font(.brandBody(11))
                            .foregroundStyle(Color.inkFaint)
                            .listRowBackground(Color.canvas)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.canvas)
        .navigationTitle("Rankings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadInitial() }
    }

    private var emptyStateMessage: String {
        let trimmedWeek = viewModel.weekInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let weekSuffix = trimmedWeek.isEmpty ? "" : ", week \(trimmedWeek)"
        return "No matchup scores yet for \(viewModel.statCategory.label.lowercased()) in \(String(viewModel.season))\(weekSuffix)."
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(RankingStatCategory.allCases) { category in
                        Button(category.label) { Task { await viewModel.setStatCategory(category) } }
                    }
                } label: {
                    filterLabel(viewModel.statCategory.label)
                }

                Menu {
                    ForEach(RankingsViewModel.seasons, id: \.self) { year in
                        Button(String(year)) { Task { await viewModel.setSeason(year) } }
                    }
                } label: {
                    filterLabel(String(viewModel.season))
                }

                TextField("All weeks", text: $viewModel.weekInput)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)

                Spacer()
            }

            Text("Signal shows how many of the 4 trend categories (matchup/recent form/situational/role trend) had a real read for that player — a high score built on 1 or 2 is much thinner than one built on all 4.")
                .font(.brandBody(11))
                .foregroundStyle(Color.inkFaint)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.surface)
    }

    private func filterLabel(_ text: String) -> some View {
        Label(text, systemImage: "chevron.down")
            .font(.brandBody(13))
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct RankingRowView: View {
    let row: RankingRow
    let unit: String

    private var seasonAvgText: String {
        guard let seasonAvg = row.seasonAvg else { return "—" }
        let base = "\(String(format: "%.1f", seasonAvg)) \(unit)"
        if let gamesPlayed = row.gamesPlayed {
            return "\(base) (\(String(gamesPlayed)) gm)"
        }
        return base
    }

    var body: some View {
        NavigationLink(value: AgentsRoute.playerDetail(row.playerId)) {
            HStack(alignment: .top, spacing: 10) {
                Text(String(row.rank))
                    .font(.brandBody(14, weight: .semibold))
                    .foregroundStyle(Color.inkFaint)
                    .frame(width: 22, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.playerName)
                        .font(.brandBody(14, weight: .medium))
                        .foregroundStyle(Color.ink)
                    Text(row.position)
                        .font(.brandBody(12))
                        .foregroundStyle(Color.inkDim)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(String(format: "%.1f", row.score))
                            .font(.brandBody(14, weight: .semibold))
                            .foregroundStyle(Color.ink)
                        SignalBadge(categoriesUsed: row.categoriesUsed)
                    }
                    Text(seasonAvgText)
                        .font(.brandBody(11))
                        .foregroundStyle(Color.inkDim)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// Web's signalBadgeClass — >=3 of 4 categories is a real trend read
/// (positive), exactly 2 is thin but present (caution), 0-1 is mostly
/// default filler (negative). A tint-at-12%-opacity pill in every case
/// here (unlike EdgeBadge/PropBadgeChip's neutral-solid special case) —
/// web's own signalBadgeClass never has a "no read at all" state to
/// distinguish, every row always has a 0-4 categoriesUsed value.
private struct SignalBadge: View {
    let categoriesUsed: Int

    var body: some View {
        Text("\(String(categoriesUsed))/4")
            .font(.brandBody(10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var color: Color {
        if categoriesUsed >= 3 { return Color.positive }
        if categoriesUsed == 2 { return Color.caution }
        return Color.negative
    }
}
