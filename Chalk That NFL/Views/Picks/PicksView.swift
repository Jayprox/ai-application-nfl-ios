//
//  PicksView.swift
//  Chalk That NFL
//
//  Mirrors PicksPage.jsx: the portfolio agent's running record (a
//  stat-tile grid from GET /picks/stats) plus every pick it's logged
//  (GET /picks), most recent first — both hardcoded to agent_name=
//  portfolio_agent_v1, the only real writer to picks_log today (see
//  PicksViewModel's own header comment). Pushed onto Record's shared
//  NavigationStack (see RecordRoute.swift), matching web's own
//  Record-group placement for Picks.
//
import SwiftUI

struct PicksView: View {
    @StateObject private var viewModel = PicksViewModel()

    private static let gridColumns = [
        GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Portfolio agent \u{2014} every pick it's logged, and how it's graded out.")
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)

                if viewModel.isLoading || viewModel.errorMessage != nil {
                    AsyncStateView(
                        loading: viewModel.isLoading,
                        error: viewModel.errorMessage,
                        loadingLabel: "Loading picks\u{2026}",
                        onRetry: { Task { await viewModel.refresh() } }
                    )
                } else {
                    if let stats = viewModel.stats {
                        statTiles(stats)
                    }

                    if viewModel.picks.isEmpty {
                        Text("No picks logged yet.")
                            .font(.brandBody(13))
                            .foregroundStyle(Color.inkDim)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(viewModel.picks) { pick in
                                PickRowView(pick: pick)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.canvas)
        .navigationTitle("Picks")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadIfNeeded() }
    }

    private func statTiles(_ stats: PicksStats) -> some View {
        let record = "\(stats.correct)-\(stats.incorrect)" + (stats.push > 0 ? "-\(stats.push)" : "")
        let hitRate = stats.hitRatePct.map { "\(PortfolioFormat.number($0))%" } ?? "\u{2014}"
        return LazyVGrid(columns: Self.gridColumns, spacing: 8) {
            StatTileView(label: "Record", value: record)
            StatTileView(label: "Hit rate", value: hitRate)
            StatTileView(label: "Pending", value: String(stats.pending))
            StatTileView(label: "Correct", value: String(stats.correct))
            StatTileView(label: "Incorrect", value: String(stats.incorrect))
            StatTileView(label: "Total", value: String(stats.total))
        }
    }
}

private struct StatTileView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.brandBody(17, weight: .semibold))
                .foregroundStyle(Color.ink)
            Text(label)
                .font(.brandBody(11))
                .foregroundStyle(Color.inkDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Mirrors PicksPage.jsx's STATUS_STYLE/STATUS_LABEL — same tone split
/// as Props' badges (PropCardView.swift): a real graded outcome
/// (correct/incorrect/push) gets its own color at 12% opacity, but
/// pending/void use a solid neutral `surface2` fill instead of a
/// tinted one.
private enum PickStatusTone {
    case positive, negative, caution, neutral

    var foreground: Color {
        switch self {
        case .positive: return Color.positive
        case .negative: return Color.negative
        case .caution: return Color.caution
        case .neutral: return Color.inkDim
        }
    }

    var background: Color {
        switch self {
        case .neutral: return Color.surface2
        default: return foreground.opacity(0.12)
        }
    }
}

private struct PickStatusBadge: View {
    let status: String

    private var label: String {
        switch status {
        case "pending": return "Pending"
        case "correct": return "Correct"
        case "incorrect": return "Incorrect"
        case "push": return "Push"
        case "void": return "Void"
        default: return status.capitalized
        }
    }

    private var tone: PickStatusTone {
        switch status {
        case "correct": return .positive
        case "incorrect": return .negative
        case "push": return .caution
        default: return .neutral
        }
    }

    var body: some View {
        Text(label)
            .font(.brandBody(11, weight: .semibold))
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tone.background)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct PickRowView: View {
    let pick: PickRow

    private static let loggedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// "away @ home", with whichever side was picked bolded — a
    /// player_stat pick carries no predicted_team_abbr, so neither
    /// side bolds (matches web's MatchupLine — that pick isn't about a
    /// side at all).
    @ViewBuilder
    private var matchupLine: some View {
        if let away = pick.awayTeamAbbr, let home = pick.homeTeamAbbr {
            let weekPrefix = pick.week.map { "Week \($0) \u{b7} " } ?? ""
            (
                Text(weekPrefix)
                    + Text(away).fontWeight(pick.predictedTeamAbbr == away ? .semibold : .regular)
                        .foregroundColor(pick.predictedTeamAbbr == away ? Color.ink : Color.inkFaint)
                    + Text(" @ ")
                    + Text(home).fontWeight(pick.predictedTeamAbbr == home ? .semibold : .regular)
                        .foregroundColor(pick.predictedTeamAbbr == home ? Color.ink : Color.inkFaint)
            )
            .font(.brandBody(11))
            .foregroundStyle(Color.inkFaint)
        }
    }

    /// Renders what was actually picked, whichever of the two picks_log
    /// shapes this row is — mirrors web's pickSummary().
    private var summary: String {
        if pick.pickType == "game_line" {
            let marketLabel = pick.market == "h2h" ? "moneyline" : (pick.market ?? "")
            let unitsSuffix = pick.units.map { " \u{b7} \(PortfolioFormat.number($0))u" } ?? ""
            return "\(pick.predictedTeamAbbr ?? "\u{2014}") (\(marketLabel))\(unitsSuffix)"
        }
        let direction = pick.predictedDirection?.uppercased() ?? ""
        let line = pick.predictedLine.map(PortfolioFormat.number) ?? ""
        return "\(pick.playerName ?? "Unknown player") \u{2014} \(direction) \(line) \(pick.statCategory ?? "")"
            .trimmingCharacters(in: .whitespaces)
    }

    private var loggedLine: String {
        var text = "Logged"
        if let createdAt = pick.createdAt, let date = BackendDate.parse(createdAt) {
            text += " \(Self.loggedFormatter.string(from: date))"
        }
        if let gradedAt = pick.gradedAt, let date = BackendDate.parse(gradedAt) {
            text += " \u{b7} Graded \(Self.loggedFormatter.string(from: date))"
        }
        return text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                matchupLine
                Text(summary)
                    .font(.brandBody(13, weight: .medium))
                    .foregroundStyle(Color.ink)
                if let reasoning = pick.reasoning, !reasoning.isEmpty {
                    Text(reasoning)
                        .font(.brandBody(11))
                        .foregroundStyle(Color.inkDim)
                }
                Text(loggedLine)
                    .font(.brandBody(11))
                    .foregroundStyle(Color.inkFaint)
            }

            Spacer(minLength: 8)

            PickStatusBadge(status: pick.status)
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
