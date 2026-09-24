//
//  EdgeView.swift
//  Chalk That NFL
//
//  Mirrors EdgePage.jsx: season/week/only-disagreements filters over a
//  plain list of model-vs-market rows. Deliberately NOT tappable rows —
//  web's own <li> here has no Link either (unlike Props/Board's game
//  cards), so this stays a read-only list. Pushed onto Agents' shared
//  NavigationStack (see AgentsRoute.swift).
//
import SwiftUI

struct EdgeView: View {
    @StateObject private var viewModel = EdgeViewModel()

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            if viewModel.weekInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Spacer()
                Text("Enter a week to see that week's games.")
                    .font(.brandBody(14))
                    .foregroundStyle(Color.inkDim)
                Spacer()
            } else if viewModel.isLoading || viewModel.errorMessage != nil {
                AsyncStateView(
                    loading: viewModel.isLoading,
                    error: viewModel.errorMessage,
                    loadingLabel: "Loading edges…",
                    onRetry: { Task { await viewModel.load() } }
                )
                Spacer()
            } else if viewModel.edges.isEmpty {
                Spacer()
                Text(
                    viewModel.onlyDisagreements
                        ? "No disagreements found for season \(String(viewModel.season)), week \(viewModel.weekInput)."
                        : "No games found for season \(String(viewModel.season)), week \(viewModel.weekInput)."
                )
                .font(.brandBody(14))
                .foregroundStyle(Color.inkDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                Spacer()
            } else {
                List {
                    ForEach(viewModel.edges) { row in
                        EdgeRowView(row: row, teamsById: viewModel.teams)
                            .listRowBackground(Color.surface)
                    }
                    Text("\(String(viewModel.edges.count)) game\(viewModel.edges.count == 1 ? "" : "s")")
                        .font(.brandBody(11))
                        .foregroundStyle(Color.inkFaint)
                        .listRowBackground(Color.canvas)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.canvas)
        .navigationTitle("Edge")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadInitial() }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(EdgeViewModel.seasons, id: \.self) { year in
                        Button(String(year)) { Task { await viewModel.setSeason(year) } }
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
                    .frame(width: 80)

                Spacer()
            }

            Toggle("Only disagreements", isOn: $viewModel.onlyDisagreements)
                .toggleStyle(.switch)
                .tint(Color.accent)
                .font(.brandBody(13))
                .foregroundStyle(Color.inkDim)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.surface)
    }
}

private struct EdgeRowView: View {
    let row: EdgeRow
    let teamsById: [Int: String]

    private var awayAbbr: String { teamsById[row.awayTeamId] ?? "AWAY" }
    private var homeAbbr: String { teamsById[row.homeTeamId] ?? "HOME" }

    private var modelAbbr: String? {
        switch row.modelFavorite {
        case "home": return homeAbbr
        case "away": return awayAbbr
        default: return nil
        }
    }

    private var marketAbbr: String? {
        switch row.marketFavorite {
        case "home": return homeAbbr
        case "away": return awayAbbr
        default: return nil
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(awayAbbr) @ \(homeAbbr)")
                    .font(.brandBody(14, weight: .medium))
                    .foregroundStyle(Color.ink)

                VStack(alignment: .leading, spacing: 2) {
                    line(label: "Model", abbr: modelAbbr, margin: row.modelMargin, source: nil)
                    line(label: "Market", abbr: marketAbbr, margin: row.marketMargin, source: row.marketSource)
                }
                .font(.brandBody(12))
                .foregroundStyle(Color.inkDim)

                if !row.note.isEmpty {
                    Text(row.note)
                        .font(.brandBody(11))
                        .foregroundStyle(Color.inkFaint)
                }
            }

            Spacer()

            EdgeBadge(edge: row.edge)
        }
        .padding(.vertical, 4)
    }

    private func line(label: String, abbr: String?, margin: Double?, source: String?) -> some View {
        HStack(spacing: 3) {
            Text("\(label):")
            if let abbr {
                Text(abbr)
                    .font(.brandBody(12, weight: .medium))
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
}
