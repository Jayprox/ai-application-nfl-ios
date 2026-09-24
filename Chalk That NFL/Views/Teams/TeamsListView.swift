//
//  TeamsListView.swift
//  Chalk That NFL
//
//  Mirrors TeamBrowsePage.jsx: all 32 teams grouped by division.
//
//  Division headers remain plain rows in the flattened list. The previous
//  blank-detail issue was caused by TeamDetailView's initially empty Group,
//  not Section nesting; see the 2026-09-24 investigation in HANDOFF.md.
//
import SwiftUI

private enum TeamsListRow: Identifiable {
    case header(String)
    case team(Team)

    var id: String {
        switch self {
        case .header(let title): return "header::\(title)"
        case .team(let team): return "team::\(team.teamId)"
        }
    }
}

private func flattenedRows(_ sections: [KeyedGroup<Team>]) -> [TeamsListRow] {
    sections.flatMap { section in
        [TeamsListRow.header(section.id)] + section.items.map(TeamsListRow.team)
    }
}

struct TeamsListView: View {
    @StateObject private var viewModel = TeamsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading || viewModel.errorMessage != nil {
                AsyncStateView(
                    loading: viewModel.isLoading,
                    error: viewModel.errorMessage,
                    loadingLabel: "Loading teams…",
                    onRetry: { Task { await viewModel.load() } }
                )
            } else {
                List {
                    ForEach(flattenedRows(viewModel.teamsByDivision)) { row in
                        switch row {
                        case .header(let title):
                            Text(title)
                                .font(.brandBody(12, weight: .semibold))
                                .foregroundStyle(Color.inkFaint)
                                .listRowBackground(Color.canvas)
                                .listRowSeparator(.hidden)
                                .padding(.top, 6)
                        case .team(let team):
                            NavigationLink(value: ResearchRoute.teamDetail(team.teamId)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(team.name)
                                            .font(.brandBody(15, weight: .medium))
                                            .foregroundStyle(Color.ink)
                                        if let city = team.city {
                                            Text(city)
                                                .font(.brandBody(12))
                                                .foregroundStyle(Color.inkFaint)
                                        }
                                    }
                                    Spacer()
                                    Text(team.abbreviation)
                                        .font(.brandBody(13, weight: .semibold))
                                        .foregroundStyle(Color.inkFaint)
                                }
                            }
                            .listRowBackground(Color.surface)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.canvas)
            }
        }
        .background(Color.canvas)
        .navigationTitle("Teams")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}
