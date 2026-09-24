//
//  GamePlayerStatsSection.swift
//  Chalk That NFL
//
//  Mirrors GameDetailPage.jsx's "Player Stats" section — SEASON stats
//  for both rosters (GET /games/:id/player-stats), with its own
//  independent team toggle AND its own independent Season Avg/Season
//  Total mode toggle (playerStatsSide/playerStatsMode in web — kept
//  deliberately separate from Live Box Score's activeSide, exactly as
//  web keeps two separate pieces of state for the two sections).
//
//  Reuses StatCategoryTable — the same generic table view Live Box
//  Score uses — fed PlayerSeasonOffenseRow/DefenseRow/SpecialTeamsRow
//  instead of the BoxScore row types, matching web's own single
//  BoxScoreCategoryTable being reused unchanged for both sections. Web
//  maps the SAME ALL_BOX_SCORE_CATEGORIES list here as Live Box Score
//  (`ALL_BOX_SCORE_CATEGORIES.map((cat) => <BoxScoreCategoryTable ...
//  rows={activePlayerStatsSide[cat.group][playerStatsMode]} />)`), so
//  this section renders all eight categories too, Punt Return/Kick
//  Return included — confirmed directly against the JSX rather than
//  assumed from the section's name.
//
//  The section header ("Player Stats") always renders; the empty-state
//  copy ("No stats synced yet this season for either roster.") and the
//  toggles+tables are mutually exclusive, matching web's own
//  `!playerStats || playerStatsSampleSize === 0 ? <p>...</p> : <div>...`
//  branch. Unlike Live Box Score / Drive Feed, this section has NO
//  freshness footer at all in the JSX — not an oversight, just what web
//  actually renders here.
//
import SwiftUI

struct GamePlayerStatsSection: View {
    let game: Game
    let sides: PlayerSeasonSides?
    let sampleSize: Int

    @State private var side: TeamSide = .away
    @State private var mode: StatsMode = .avg

    private enum TeamSide { case home, away }
    private enum StatsMode { case avg, total }

    private var hasData: Bool { sides != nil && sampleSize > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Player Stats")
                .font(.brandBody(13, weight: .semibold))
                .foregroundStyle(Color.inkFaint)
                .textCase(.uppercase)

            if !hasData {
                Text("No stats synced yet this season for either roster.")
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)
            } else if let sides {
                content(for: side == .home ? sides.home : sides.away)
            }
        }
    }

    private func content(for split: PlayerSeasonTeamSplit) -> some View {
        let offenseRows = mode == .avg ? split.offense.avg : split.offense.total
        let defenseRows = mode == .avg ? split.defense.avg : split.defense.total
        let specialTeamsRows = mode == .avg ? split.specialTeams.avg : split.specialTeams.total

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                sideButton(title: game.awayTeamAbbr, target: .away)
                sideButton(title: game.homeTeamAbbr, target: .home)
                Spacer(minLength: 12)
                modeButton(title: "Season Avg", target: .avg)
                modeButton(title: "Season Total", target: .total)
            }

            VStack(alignment: .leading, spacing: 0) {
                StatCategoryTable(
                    title: "Passing", rows: offenseRows,
                    isIncluded: { ($0.passAttempts ?? 0) > 0 },
                    columns: passingColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Rushing", rows: offenseRows,
                    isIncluded: { ($0.rushAttempts ?? 0) > 0 },
                    columns: rushingColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Receiving", rows: offenseRows,
                    isIncluded: { ($0.targets ?? 0) > 0 || ($0.receptions ?? 0) > 0 },
                    columns: receivingColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Kicking", rows: specialTeamsRows,
                    isIncluded: { ($0.fgAttempts ?? 0) > 0 || ($0.xpAttempts ?? 0) > 0 },
                    columns: kickingColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Punting", rows: specialTeamsRows,
                    isIncluded: { ($0.punts ?? 0) > 0 },
                    columns: puntingColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Defense", rows: defenseRows,
                    isIncluded: defenseIncluded,
                    columns: defenseColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Punt Return", rows: specialTeamsRows,
                    isIncluded: { ($0.puntReturnYards ?? 0) > 0 },
                    columns: puntReturnColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Kick Return", rows: specialTeamsRows,
                    isIncluded: { ($0.kickReturnYards ?? 0) > 0 },
                    columns: kickReturnColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
            }
        }
    }

    private func sideButton(title: String, target: TeamSide) -> some View {
        let isActive = side == target
        return Button {
            side = target
        } label: {
            Text(title)
                .font(.brandBody(12, weight: .medium))
                .foregroundStyle(isActive ? Color.onAccent : Color.inkDim)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isActive ? Color.accent : Color.surface2)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func modeButton(title: String, target: StatsMode) -> some View {
        let isActive = mode == target
        return Button {
            mode = target
        } label: {
            Text(title)
                .font(.brandBody(11, weight: .medium))
                .foregroundStyle(isActive ? Color.onAccent : Color.inkDim)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? Color.accent : Color.surface2)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Season Avg mode shows one decimal place (matches web's raw-float
    /// display closely enough to be readable without reproducing the
    /// exact float artifact — see PlayerSeasonStatsModels.swift's header
    /// for why this is a deliberate display choice, not a parity gap).
    /// Season Total mode trims a whole-number's trailing ".0", the same
    /// convention PortfolioFormat.number already uses for plain summed
    /// counts elsewhere in the app.
    private func statText(_ value: Double?) -> String {
        guard let value else { return mode == .avg ? "0.0" : "0" }
        return mode == .avg ? String(format: "%.1f", value) : PortfolioFormat.number(value)
    }

    private var passingColumns: [StatColumn<PlayerSeasonOffenseRow>] {
        [
            StatColumn(key: "c", label: "C", value: { self.statText($0.passCompletions) }),
            StatColumn(key: "att", label: "ATT", value: { self.statText($0.passAttempts) }),
            StatColumn(key: "yds", label: "YDS", value: { self.statText($0.passingYards) }),
            StatColumn(key: "td", label: "TD", value: { self.statText($0.passingTds) }),
            StatColumn(key: "int", label: "INT", value: { self.statText($0.interceptionsThrown) }),
        ]
    }

    private var rushingColumns: [StatColumn<PlayerSeasonOffenseRow>] {
        [
            StatColumn(key: "att", label: "ATT", value: { self.statText($0.rushAttempts) }),
            StatColumn(key: "yds", label: "YDS", value: { self.statText($0.rushingYards) }),
            StatColumn(key: "td", label: "TD", value: { self.statText($0.rushingTds) }),
            StatColumn(key: "fum", label: "FUM", value: { self.statText($0.fumbles) }),
        ]
    }

    private var receivingColumns: [StatColumn<PlayerSeasonOffenseRow>] {
        [
            StatColumn(key: "rec", label: "REC", value: { self.statText($0.receptions) }),
            StatColumn(key: "tgt", label: "TGT", value: { self.statText($0.targets) }),
            StatColumn(key: "yds", label: "YDS", value: { self.statText($0.receivingYards) }),
            StatColumn(key: "td", label: "TD", value: { self.statText($0.receivingTds) }),
        ]
    }

    private var kickingColumns: [StatColumn<PlayerSeasonSpecialTeamsRow>] {
        [
            StatColumn(key: "fg", label: "FG", value: { self.statText($0.fgMade) }),
            StatColumn(key: "fga", label: "FGA", value: { self.statText($0.fgAttempts) }),
            StatColumn(key: "lng", label: "LNG", value: { self.statText($0.longestFg) }),
            StatColumn(key: "xp", label: "XP", value: { self.statText($0.xpMade) }),
            StatColumn(key: "xpa", label: "XPA", value: { self.statText($0.xpAttempts) }),
        ]
    }

    private var puntingColumns: [StatColumn<PlayerSeasonSpecialTeamsRow>] {
        [
            StatColumn(key: "punt", label: "PUNT", value: { self.statText($0.punts) }),
            StatColumn(key: "yds", label: "YDS", value: { self.statText($0.puntYards) }),
            StatColumn(key: "avg", label: "AVG", value: { self.statText($0.puntAvg) }),
        ]
    }

    private var defenseColumns: [StatColumn<PlayerSeasonDefenseRow>] {
        [
            StatColumn(key: "solo", label: "SOLO", value: { self.statText($0.tacklesSolo) }),
            StatColumn(key: "ast", label: "AST", value: { self.statText($0.tacklesAssist) }),
            StatColumn(key: "sack", label: "SACK", value: { self.statText($0.sacks) }),
            StatColumn(key: "int", label: "INT", value: { self.statText($0.interceptions) }),
            StatColumn(key: "pd", label: "PD", value: { self.statText($0.passesDefended) }),
            StatColumn(key: "ff", label: "FF", value: { self.statText($0.forcedFumbles) }),
            StatColumn(key: "fr", label: "FR", value: { self.statText($0.fumbleRecoveries) }),
            StatColumn(key: "td", label: "TD", value: { self.statText($0.defensiveTds) }),
        ]
    }

    private func defenseIncluded(_ row: PlayerSeasonDefenseRow) -> Bool {
        (row.tacklesSolo ?? 0) > 0 || (row.tacklesAssist ?? 0) > 0 || (row.sacks ?? 0) > 0 ||
        (row.interceptions ?? 0) > 0 || (row.passesDefended ?? 0) > 0 || (row.forcedFumbles ?? 0) > 0 ||
        (row.fumbleRecoveries ?? 0) > 0 || (row.defensiveTds ?? 0) > 0
    }

    private var puntReturnColumns: [StatColumn<PlayerSeasonSpecialTeamsRow>] {
        [StatColumn(key: "yds", label: "YDS", value: { self.statText($0.puntReturnYards) })]
    }

    private var kickReturnColumns: [StatColumn<PlayerSeasonSpecialTeamsRow>] {
        [StatColumn(key: "yds", label: "YDS", value: { self.statText($0.kickReturnYards) })]
    }
}
