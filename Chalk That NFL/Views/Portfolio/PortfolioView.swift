//
//  PortfolioView.swift
//  Chalk That NFL
//
//  Mirrors PortfolioPage.jsx: season/week/max-picks/unit-size controls,
//  a Preview slate / Build & log slate button pair, and the resulting
//  slate — every slate item is, by construction, a model/market
//  disagreement (buildSlate always calls listEdges with
//  onlyDisagreements: true), so unlike Edge there's no "agrees/no
//  signal" case to badge here; every card already IS a disagreement,
//  labeled with how wide model_margin is. Pushed onto Agents' shared
//  NavigationStack (see AgentsRoute.swift), matching web's own
//  Agents-group placement for Portfolio.
//
import SwiftUI

struct PortfolioView: View {
    @StateObject private var viewModel = PortfolioViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(
                    "Builds a slate of game-line picks from the edge agent's strongest disagreements, sized flat " +
                    "by unit — a distinct concern from \u{201c}which picks are good\u{201d} (that\u{2019}s Edge). " +
                    "Preview costs nothing and logs nothing; Build & log actually writes the picks (visible on " +
                    "the Picks tab, graded like any other agent's picks)."
                )
                .font(.brandBody(13))
                .foregroundStyle(Color.inkDim)

                filterBar
                actionButtons
                statusMessages

                if let result = viewModel.result, !viewModel.isLoading {
                    resultSection(result)
                }
            }
            .padding()
        }
        .background(Color.canvas)
        .navigationTitle("Portfolio")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadInitial() }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(PortfolioViewModel.seasons, id: \.self) { year in
                    Button(String(year)) { viewModel.setSeason(year) }
                }
            } label: {
                Label(String(viewModel.season), systemImage: "chevron.down")
                    .font(.brandBody(13))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            TextField("Week", text: $viewModel.weekInput)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 64)

            TextField("Max picks", text: $viewModel.maxPicksInput)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 84)

            TextField("Unit size", text: $viewModel.unitSizeInput)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 84)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                Task { await viewModel.run(dryRun: true) }
            } label: {
                Text("Preview slate")
                    .font(.brandBody(14, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.line, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .disabled(!viewModel.canRun)
            .opacity(viewModel.canRun ? 1 : 0.4)

            Button {
                Task { await viewModel.run(dryRun: false) }
            } label: {
                Text("Build & log slate")
                    .font(.brandBody(14, weight: .medium))
                    .foregroundStyle(Color.onAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .disabled(!viewModel.canRun)
            .opacity(viewModel.canRun ? 1 : 0.4)
        }
    }

    @ViewBuilder
    private var statusMessages: some View {
        if viewModel.trimmedWeek.isEmpty {
            Text("Enter a week to build a slate for it.")
                .font(.brandBody(13))
                .foregroundStyle(Color.inkDim)
        }
        if viewModel.isLoading {
            Text(viewModel.mode == .build ? "Building\u{2026}" : "Previewing\u{2026}")
                .font(.brandBody(13))
                .foregroundStyle(Color.inkFaint)
        }
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.brandBody(13))
                .foregroundStyle(Color.negative)
        }
    }

    private func resultSection(_ result: PortfolioSlateResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summaryText(result))
                .font(.brandBody(13))
                .foregroundStyle(Color.inkDim)

            if result.slate.isEmpty {
                Text("No picks — no disagreements met the bar for this week.")
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)
            } else {
                VStack(spacing: 8) {
                    ForEach(result.slate) { pick in
                        PortfolioSlateRowView(pick: pick, teams: viewModel.teams)
                    }
                }
            }

            if !result.skipped.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skipped (\(result.skipped.count))")
                        .font(.brandBody(11, weight: .medium))
                        .foregroundStyle(Color.inkDim)
                    ForEach(result.skipped) { skip in
                        Text("\(skip.gameId): \(skip.reason)")
                            .font(.brandBody(11))
                            .foregroundStyle(Color.inkFaint)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func summaryText(_ result: PortfolioSlateResult) -> String {
        let verb = viewModel.mode == .build ? "Logged" : "Would log"
        let pickWord = result.picked == 1 ? "pick" : "picks"
        let considerWord = result.considered == 1 ? "disagreement" : "disagreements"
        let unitWord = result.unitSize == 1 ? "unit" : "units"
        var text = "\(verb) \(result.picked) \(pickWord) from \(result.considered) \(considerWord) considered, " +
            "at \(PortfolioFormat.number(result.unitSize)) \(unitWord) each."
        if viewModel.mode == .build && result.picked > 0 {
            text += " See the Picks tab to track how they grade out."
        }
        return text
    }
}

/// Matches JS's default Number-to-string formatting (no trailing ".0"
/// for whole numbers) — same convention as OddsBadgeLogic.formatNumber.
enum PortfolioFormat {
    static func number(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return String(value)
    }
}

private struct PortfolioSlateRowView: View {
    let pick: PortfolioSlateItem
    let teams: [Int: String]

    private var awayAbbr: String { teams[pick.awayTeamId] ?? "AWAY" }
    private var homeAbbr: String { teams[pick.homeTeamId] ?? "HOME" }

    private var pickedAbbr: String? {
        if pick.predictedTeamId == pick.homeTeamId { return homeAbbr }
        if pick.predictedTeamId == pick.awayTeamId { return awayAbbr }
        return nil
    }

    private var unitsLabel: String {
        let word = pick.units == 1 ? "unit" : "units"
        return "\(PortfolioFormat.number(pick.units)) \(word)"
    }

    private var marginLabel: String {
        if let margin = pick.modelMargin {
            return "by \(String(format: "%.1f", margin))"
        }
        return "no margin"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(awayAbbr) @ \(homeAbbr)")
                    .font(.brandBody(14, weight: .medium))
                    .foregroundStyle(Color.ink)

                (
                    Text("Pick: ")
                        + Text(pickedAbbr ?? "\u{2014}").fontWeight(.medium).foregroundColor(Color.ink)
                        + Text(" \u{b7} \(unitsLabel) \u{b7} \(pick.market)")
                )
                .font(.brandBody(12))
                .foregroundStyle(Color.inkDim)

                if let reasoning = pick.reasoning, !reasoning.isEmpty {
                    Text(reasoning)
                        .font(.brandBody(11))
                        .foregroundStyle(Color.inkFaint)
                }
            }

            Spacer(minLength: 8)

            Text(marginLabel)
                .font(.brandBody(12, weight: .medium))
                .foregroundStyle(Color.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(12)
        .background(Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
