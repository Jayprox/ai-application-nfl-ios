//
//  GameBoxScoreSection.swift
//  Chalk That NFL
//
//  Mirrors GameDetailPage.jsx's "Live Box Score" section — a per-team
//  toggle (activeSide) over this GAME's actual played stat lines (GET
//  /games/:id/boxscore), a "Top Performers" leaders strip computed from
//  the offense rows, and one StatCategoryTable per category in
//  ALL_BOX_SCORE_CATEGORIES order: Passing, Rushing, Receiving, Kicking,
//  Punting, Defense, Punt Return, Kick Return.
//
//  The section header ("Live Box Score") always renders — same as web's
//  <section><h2>...</h2>{condition ? empty : content}</section> shape —
//  with the empty-state copy branching on game.status exactly like the
//  JSX: "Box score available once the game kicks off." while scheduled,
//  "No box score synced yet for this game." otherwise. The "Top
//  Performers" heading itself always shows once there IS box score data
//  (web renders <TopPerformers/> unconditionally and lets that
//  component return null when there are no leaders) — only the leader
//  list under it is conditional.
//
//  Top Performers ports web's teamLeaders()/topByStat()/LEADER_CATEGORIES
//  exactly: for each of Passing/Rushing/Receiving, the offense row with
//  the max value of that category's yards stat, excluded entirely if
//  that max is <= 0 (nobody to lead with), and the ", N TD" suffix only
//  appended when the TD count is a JS-truthy value — i.e. > 0, not just
//  non-nil, since web's `{td && ...}` treats 0 as falsy too.
//
//  Footer text ("Box score as of {clock time}[— updates...]") only
//  renders when freshness.synced_at is present, matching web's own
//  `{boxscoreSyncedAtLabel && <p>...}` guard — it is an ABSOLUTE
//  wall-clock time (RelativeTime.clockTimeLabel), not a relative
//  "synced Nm ago" bucket, since that's what GameDetailPage.jsx's own
//  formatSyncedAt() actually renders for this page (see RelativeTime.
//  swift's header comment on why this differs from Props/Rankings).
//
import SwiftUI

/// Pure leader-computation logic, kept separate from the View — mirrors
/// GameDetailPage.jsx's topByStat()/teamLeaders()/LEADER_CATEGORIES.
enum GameBoxScoreLeaders {
    struct Leader {
        let label: String
        let row: BoxScoreOffenseRow
        let yards: Int
        let touchdowns: Int?
    }

    /// (label, yards keypath, touchdowns keypath) — same three
    /// categories/order as web's LEADER_CATEGORIES.
    private static let categories: [(label: String, yards: (BoxScoreOffenseRow) -> Int?, tds: (BoxScoreOffenseRow) -> Int?)] = [
        ("Passing", { $0.passingYards }, { $0.passingTds }),
        ("Rushing", { $0.rushingYards }, { $0.rushingTds }),
        ("Receiving", { $0.receivingYards }, { $0.receivingTds }),
    ]

    static func leaders(offenseRows: [BoxScoreOffenseRow]) -> [Leader] {
        categories.compactMap { category in
            let best = offenseRows.max { (category.yards($0) ?? 0) < (category.yards($1) ?? 0) }
            guard let best, let yards = category.yards(best), yards > 0 else { return nil }
            return Leader(label: category.label, row: best, yards: yards, touchdowns: category.tds(best))
        }
    }
}

struct GameBoxScoreSection: View {
    let game: Game
    let sides: BoxScoreSides?
    let sampleSize: Int
    let syncedAt: String?

    @State private var activeSide: TeamSide = .away

    private enum TeamSide { case home, away }

    private var hasData: Bool { sides != nil && sampleSize > 0 }

    private func activeSplit(_ sides: BoxScoreSides) -> BoxScoreTeamSplit {
        activeSide == .home ? sides.home : sides.away
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Box Score")
                .font(.brandBody(13, weight: .semibold))
                .foregroundStyle(Color.inkFaint)
                .textCase(.uppercase)

            if !hasData {
                Text(game.status == "scheduled"
                     ? "Box score available once the game kicks off."
                     : "No box score synced yet for this game.")
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)
            } else if let sides {
                content(for: activeSplit(sides))
            }
        }
    }

    private func content(for split: BoxScoreTeamSplit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sideToggle

            VStack(alignment: .leading, spacing: 4) {
                Text("Top Performers")
                    .font(.brandBody(11, weight: .medium))
                    .foregroundStyle(Color.inkDim)

                let leaders = GameBoxScoreLeaders.leaders(offenseRows: split.offense)
                if !leaders.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(leaders, id: \.label) { leader in
                            leaderRow(leader)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                StatCategoryTable(
                    title: "Passing", rows: split.offense,
                    isIncluded: { ($0.passAttempts ?? 0) > 0 },
                    columns: passingColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Rushing", rows: split.offense,
                    isIncluded: { ($0.rushAttempts ?? 0) > 0 },
                    columns: rushingColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Receiving", rows: split.offense,
                    isIncluded: { ($0.targets ?? 0) > 0 || ($0.receptions ?? 0) > 0 },
                    columns: receivingColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Kicking", rows: split.specialTeams,
                    isIncluded: { ($0.fgAttempts ?? 0) > 0 || ($0.xpAttempts ?? 0) > 0 },
                    columns: kickingColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Punting", rows: split.specialTeams,
                    isIncluded: { ($0.punts ?? 0) > 0 },
                    columns: puntingColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Defense", rows: split.defense,
                    isIncluded: defenseIncluded,
                    columns: defenseColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Punt Return", rows: split.specialTeams,
                    isIncluded: { ($0.puntReturnYards ?? 0) > 0 },
                    columns: puntReturnColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
                StatCategoryTable(
                    title: "Kick Return", rows: split.specialTeams,
                    isIncluded: { ($0.kickReturnYards ?? 0) > 0 },
                    columns: kickReturnColumns,
                    playerId: { $0.playerId }, playerName: { $0.fullName }, playerPosition: { $0.position }
                )
            }

            if let label = RelativeTime.clockTimeLabel(syncedAt) {
                Text("Box score as of \(label)" +
                    (game.status == "in_progress" ? " — updates every few minutes while the game is live." : ""))
                    .font(.brandBody(11))
                    .foregroundStyle(Color.inkFaint)
            }
        }
    }

    private var sideToggle: some View {
        HStack(spacing: 6) {
            sideButton(title: game.awayTeamAbbr, side: .away)
            sideButton(title: game.homeTeamAbbr, side: .home)
        }
    }

    private func sideButton(title: String, side: TeamSide) -> some View {
        let isActive = activeSide == side
        return Button {
            activeSide = side
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

    private func leaderRow(_ leader: GameBoxScoreLeaders.Leader) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text(leader.label)
                    .font(.brandBody(10, weight: .medium))
                    .foregroundStyle(Color.inkFaint)
                NavigationLink {
                    PlayerDetailView(playerId: leader.row.playerId)
                } label: {
                    Text(leader.row.fullName)
                        .font(.brandBody(13, weight: .medium))
                        .foregroundStyle(Color.ink)
                }
            }
            Spacer()
            Text(leaderLine(leader))
                .font(.brandBody(12))
                .foregroundStyle(Color.inkDim)
        }
        .padding(10)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// "{yards} YDS" or "{yards} YDS, {td} TD" — the TD clause only
    /// appears when td is JS-truthy (i.e. > 0), matching `{td && ...}`.
    private func leaderLine(_ leader: GameBoxScoreLeaders.Leader) -> String {
        var text = "\(leader.yards) YDS"
        if let td = leader.touchdowns, td > 0 {
            text += ", \(td) TD"
        }
        return text
    }

    private func intText(_ value: Int?) -> String { String(value ?? 0) }
    private func sacksText(_ value: Double?) -> String { PropGradingLogic.formatLine(value ?? 0) }

    private var passingColumns: [StatColumn<BoxScoreOffenseRow>] {
        [
            StatColumn(key: "c", label: "C", value: { self.intText($0.passCompletions) }),
            StatColumn(key: "att", label: "ATT", value: { self.intText($0.passAttempts) }),
            StatColumn(key: "yds", label: "YDS", value: { self.intText($0.passingYards) }),
            StatColumn(key: "td", label: "TD", value: { self.intText($0.passingTds) }),
            StatColumn(key: "int", label: "INT", value: { self.intText($0.interceptionsThrown) }),
        ]
    }

    private var rushingColumns: [StatColumn<BoxScoreOffenseRow>] {
        [
            StatColumn(key: "att", label: "ATT", value: { self.intText($0.rushAttempts) }),
            StatColumn(key: "yds", label: "YDS", value: { self.intText($0.rushingYards) }),
            StatColumn(key: "td", label: "TD", value: { self.intText($0.rushingTds) }),
            StatColumn(key: "fum", label: "FUM", value: { self.intText($0.fumbles) }),
        ]
    }

    private var receivingColumns: [StatColumn<BoxScoreOffenseRow>] {
        [
            StatColumn(key: "rec", label: "REC", value: { self.intText($0.receptions) }),
            StatColumn(key: "tgt", label: "TGT", value: { self.intText($0.targets) }),
            StatColumn(key: "yds", label: "YDS", value: { self.intText($0.receivingYards) }),
            StatColumn(key: "td", label: "TD", value: { self.intText($0.receivingTds) }),
        ]
    }

    private var kickingColumns: [StatColumn<BoxScoreSpecialTeamsRow>] {
        [
            StatColumn(key: "fg", label: "FG", value: { self.intText($0.fgMade) }),
            StatColumn(key: "fga", label: "FGA", value: { self.intText($0.fgAttempts) }),
            StatColumn(key: "lng", label: "LNG", value: { self.intText($0.longestFg) }),
            StatColumn(key: "xp", label: "XP", value: { self.intText($0.xpMade) }),
            StatColumn(key: "xpa", label: "XPA", value: { self.intText($0.xpAttempts) }),
        ]
    }

    private var puntingColumns: [StatColumn<BoxScoreSpecialTeamsRow>] {
        [
            StatColumn(key: "punt", label: "PUNT", value: { self.intText($0.punts) }),
            StatColumn(key: "yds", label: "YDS", value: { self.intText($0.puntYards) }),
            StatColumn(key: "avg", label: "AVG", value: { self.sacksText($0.puntAvg) }),
        ]
    }

    private var defenseColumns: [StatColumn<BoxScoreDefenseRow>] {
        [
            StatColumn(key: "solo", label: "SOLO", value: { self.intText($0.tacklesSolo) }),
            StatColumn(key: "ast", label: "AST", value: { self.intText($0.tacklesAssist) }),
            StatColumn(key: "sack", label: "SACK", value: { self.sacksText($0.sacks) }),
            StatColumn(key: "int", label: "INT", value: { self.intText($0.interceptions) }),
            StatColumn(key: "pd", label: "PD", value: { self.intText($0.passesDefended) }),
            StatColumn(key: "ff", label: "FF", value: { self.intText($0.forcedFumbles) }),
            StatColumn(key: "fr", label: "FR", value: { self.intText($0.fumbleRecoveries) }),
            StatColumn(key: "td", label: "TD", value: { self.intText($0.defensiveTds) }),
        ]
    }

    private func defenseIncluded(_ row: BoxScoreDefenseRow) -> Bool {
        (row.tacklesSolo ?? 0) > 0 || (row.tacklesAssist ?? 0) > 0 || (row.sacks ?? 0) > 0 ||
        (row.interceptions ?? 0) > 0 || (row.passesDefended ?? 0) > 0 || (row.forcedFumbles ?? 0) > 0 ||
        (row.fumbleRecoveries ?? 0) > 0 || (row.defensiveTds ?? 0) > 0
    }

    private var puntReturnColumns: [StatColumn<BoxScoreSpecialTeamsRow>] {
        [StatColumn(key: "yds", label: "YDS", value: { self.intText($0.puntReturnYards) })]
    }

    private var kickReturnColumns: [StatColumn<BoxScoreSpecialTeamsRow>] {
        [StatColumn(key: "yds", label: "YDS", value: { self.intText($0.kickReturnYards) })]
    }
}
