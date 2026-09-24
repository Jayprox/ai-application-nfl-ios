//
//  PlayerStatsSection.swift
//  Chalk That NFL
//
//  Mirrors PlayerDetailPage.jsx's insights card + scope tabs + season/
//  filter selectors + StatGrid/GameLogTable/EmptyStatsMessage block
//  (2026-09-22, "match the web version" full-parity phase). Two pieces:
//
//  - PlayerInsightsSection: GET /insights/players/:id's 4 categories,
//    rendered as PlayerInsights.jsx's cards -- renders nothing at all
//    when every category came back label: null, matching that
//    component's own "don't fake a reading" convention.
//
//  - PlayerStatsSection: the scope tab bar (Season Avg/Season Total/
//    Last 5/Career/Game Log), the season Menu (hidden for Career, same
//    as the JSX's `{scope !== 'career' && <select>...}`), the three
//    split filter Menus + Clear button, and the StatGrid/GameLogTable/
//    EmptyStatsMessage content below them. Owns its own scope/season/
//    filter @State (same "local UI state, not ViewModel state"
//    convention GamePlayerStatsSection's side/mode toggles already
//    use) but is wired to PlayerDetailViewModel (passed in as
//    @ObservedObject, not owned here) since selecting a new scope/
//    filter combination has to trigger a NEW POST /query call, not just
//    re-render already-loaded data -- unlike GamePlayerStatsSection's
//    toggles, which only re-slice data that's already all loaded.
//
//  Refetching on selection change uses `.task(id:)` keyed to every
//  query-relevant field: SwiftUI cancels the in-flight task and starts
//  a fresh one whenever that key changes, which is this app's structured-
//  concurrency equivalent of useStatsQuery.js's own bodyKey-driven
//  useEffect. PlayerDetailViewModel.fetchStats(...) ALSO guards its own
//  writes with a generation counter (see that file's header) as
//  defense-in-depth -- the same "don't trust started-first to mean
//  finishes-first" reasoning useStatsQuery.js's own comment gives for
//  why bodyKey-comparison alone wasn't enough there.
//
import SwiftUI

struct PlayerInsightsSection: View {
    let insights: [PlayerInsightEntry]

    private var withSignal: [PlayerInsightEntry] {
        insights.filter { $0.label != nil }
    }

    var body: some View {
        if !withSignal.isEmpty {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(withSignal) { entry in
                    card(for: entry)
                }
            }
        }
    }

    private func card(for entry: PlayerInsightEntry) -> some View {
        let label = entry.label ?? ""
        let tone = PlayerInsightDisplay.tone(label)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                Text(PlayerInsightDisplay.categoryLabel(entry.category))
                    .font(.brandBody(11, weight: .semibold))
                    .foregroundStyle(Color.inkFaint)
                    .textCase(.uppercase)
                Spacer(minLength: 4)
                Text(PlayerInsightDisplay.formatLabel(label))
                    .font(.brandBody(11, weight: .medium))
                    .foregroundStyle(tone.foreground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tone.background)
                    .clipShape(Capsule())
            }
            if let note = entry.note, !note.isEmpty {
                Text(note)
                    .font(.brandBody(11))
                    .foregroundStyle(Color.inkDim)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension PlayerInsightDisplay.Tone {
    var foreground: Color {
        switch self {
        case .positive: return .positive
        case .negative: return .negative
        case .neutral: return .inkDim
        }
    }

    var background: Color {
        switch self {
        case .positive: return .positive.opacity(0.12)
        case .negative: return .negative.opacity(0.12)
        case .neutral: return .surface2
        }
    }
}

struct PlayerStatsSection: View {
    let player: PlayerDetail
    @ObservedObject var viewModel: PlayerDetailViewModel

    @State private var scope = "season"
    @State private var season = PlayerDetailViewModel.currentSeason
    @State private var homeAway = ""
    @State private var gameSlot = ""
    @State private var weatherCondition = ""

    private var hasActiveSplit: Bool {
        !homeAway.isEmpty || !gameSlot.isEmpty || !weatherCondition.isEmpty
    }

    private var columns: [PlayerStatColumnDef] {
        PlayerStatColumns.forPositionGroup(player.positionGroup)
    }

    /// Everything a new POST /query call depends on -- mirrors
    /// useStatsQuery.js's own `bodyKey`. `.task(id:)` below reruns
    /// runFetch() whenever this changes.
    private struct StatsQueryKey: Equatable {
        let playerId: String
        let scope: String
        let season: Int
        let homeAway: String
        let gameSlot: String
        let weatherCondition: String
    }

    private var queryKey: StatsQueryKey {
        StatsQueryKey(
            playerId: player.playerId, scope: scope, season: season,
            homeAway: homeAway, gameSlot: gameSlot, weatherCondition: weatherCondition
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            scopeTabs
            filters
            content
            footer
        }
        .task(id: queryKey) { await runFetch() }
    }

    private func runFetch() async {
        await viewModel.fetchStats(
            playerId: player.playerId,
            positionGroup: player.positionGroup,
            scope: scope,
            season: season,
            homeAway: homeAway.isEmpty ? nil : homeAway,
            gameSlot: gameSlot.isEmpty ? nil : gameSlot,
            weatherCondition: weatherCondition.isEmpty ? nil : weatherCondition
        )
    }

    private var scopeTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PlayerStatScopes.all) { s in
                    let isActive = scope == s.id
                    Button {
                        scope = s.id
                    } label: {
                        Text(s.label)
                            .font(.brandBody(12, weight: .medium))
                            .foregroundStyle(isActive ? Color.onAccent : Color.inkDim)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isActive ? Color.accent : Color.surface2)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Hidden for Career -- that scope ignores season entirely
            // (see PlayerQueryRequestBody's own comment), same as the
            // JSX's `{scope !== 'career' && <select>...}` guard.
            if scope != "career" {
                Menu {
                    ForEach(PlayerDetailViewModel.availableSeasons, id: \.self) { year in
                        Button("\(String(year)) season") { season = year }
                    }
                } label: {
                    filterLabel("\(season) season")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Menu {
                        Button("Home/Away: All") { homeAway = "" }
                        Button("Home only") { homeAway = "home" }
                        Button("Away only") { homeAway = "away" }
                    } label: {
                        filterLabel(homeAwayLabel)
                    }

                    Menu {
                        Button("Time Slot: All") { gameSlot = "" }
                        ForEach(PlayerSplitOptions.gameSlots, id: \.value) { opt in
                            Button(opt.label) { gameSlot = opt.value }
                        }
                    } label: {
                        filterLabel(gameSlotLabel)
                    }

                    Menu {
                        Button("Weather: All") { weatherCondition = "" }
                        ForEach(PlayerSplitOptions.weather, id: \.value) { opt in
                            Button(opt.label) { weatherCondition = opt.value }
                        }
                    } label: {
                        filterLabel(weatherLabel)
                    }

                    if hasActiveSplit {
                        Button("Clear") {
                            homeAway = ""
                            gameSlot = ""
                            weatherCondition = ""
                        }
                        .font(.brandBody(12, weight: .medium))
                        .foregroundStyle(Color.inkDim)
                        .underline()
                    }
                }
            }
        }
    }

    private var homeAwayLabel: String {
        switch homeAway {
        case "home": return "Home only"
        case "away": return "Away only"
        default: return "Home/Away: All"
        }
    }

    private var gameSlotLabel: String {
        PlayerSplitOptions.gameSlots.first { $0.value == gameSlot }?.label ?? "Time Slot: All"
    }

    private var weatherLabel: String {
        PlayerSplitOptions.weather.first { $0.value == weatherCondition }?.label ?? "Weather: All"
    }

    private func filterLabel(_ text: String) -> some View {
        Label(text, systemImage: "chevron.down")
            .font(.brandBody(12, weight: .medium))
            .foregroundStyle(Color.ink)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.statsLoading || viewModel.statsErrorMessage != nil {
            AsyncStateView(
                loading: viewModel.statsLoading,
                error: viewModel.statsErrorMessage,
                loadingLabel: "Loading stats…",
                onRetry: { Task { await runFetch() } }
            )
        } else if viewModel.statsSampleSize == 0 {
            Text(PlayerStatsEmptyMessage.text(scope: scope, season: season, hasActiveSplit: hasActiveSplit, playerName: player.fullName))
                .font(.brandBody(13))
                .foregroundStyle(Color.inkDim)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .background(Color.canvas)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if scope == "game_log" {
            gameLogTable
        } else {
            statGrid
        }
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 1) {
            ForEach(viewModel.statEntries) { entry in
                HStack {
                    Text(entry.label)
                        .font(.brandBody(12))
                        .foregroundStyle(Color.inkDim)
                    Spacer()
                    Text(entry.displayValue)
                        .font(.brandBody(13, weight: .semibold))
                        .foregroundStyle(Color.ink)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.surface)
            }
        }
        .background(Color.line)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private let gameLogLeadColumnWidth: CGFloat = 44
    private let gameLogStatColumnWidth: CGFloat = 46

    private var gameLogTable: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text("Wk").frame(width: 24, alignment: .leading)
                    Text("Date").frame(width: gameLogLeadColumnWidth, alignment: .leading)
                    Text("Opp").frame(width: gameLogLeadColumnWidth, alignment: .leading)
                    ForEach(columns) { col in
                        Text(col.label)
                            .frame(width: gameLogStatColumnWidth, alignment: .trailing)
                    }
                }
                .font(.brandBody(10, weight: .medium))
                .foregroundStyle(Color.inkFaint)
                .padding(.bottom, 3)

                ForEach(viewModel.gameLogRows) { row in
                    HStack(spacing: 4) {
                        Text(String(row.week))
                            .frame(width: 24, alignment: .leading)
                        Text(row.dateLabel)
                            .frame(width: gameLogLeadColumnWidth, alignment: .leading)
                        Text(row.opponentLabel)
                            .frame(width: gameLogLeadColumnWidth, alignment: .leading)
                        ForEach(row.cells) { cell in
                            Text(cell.value)
                                .frame(width: gameLogStatColumnWidth, alignment: .trailing)
                        }
                    }
                    .font(.brandBody(12))
                    .foregroundStyle(Color.ink)
                    .padding(.vertical, 3)
                    .overlay(alignment: .bottom) {
                        Rectangle().frame(height: 1).foregroundStyle(Color.line)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if viewModel.statsSampleSize > 0 {
            Text("\(String(viewModel.statsSampleSize)) game\(viewModel.statsSampleSize == 1 ? "" : "s") · \(RelativeTime.sinceSynced(viewModel.statsSyncedAt))")
                .font(.brandBody(11))
                .foregroundStyle(Color.inkFaint)
        }
    }
}
