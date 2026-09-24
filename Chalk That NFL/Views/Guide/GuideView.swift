//
//  GuideView.swift
//  Chalk That NFL
//
//  A permanent, always-accessible reference explaining what every part
//  of the app does and how the pieces fit together. Added 2026-09-24 on
//  request ("a guide for the app so users have a better understanding"),
//  built once and shared conceptually with the same-day web Guide page
//  (backend-api repo's frontend/src/pages/GuidePage.jsx) — same section
//  set, same content, same order, adapted to a native List instead of a
//  scrolling web page with jump-links. Reached from AccountMenuButton
//  (Views/ComingSoonView.swift), the one piece of chrome already shown
//  on every tab, rather than a new tab of its own — mirrors web's own
//  choice of a persistent top-level nav item rather than nesting it
//  under one of the three groups.
//
//  Static content only, no API calls — this describes the app's
//  structure and reasoning, which doesn't change screen to screen. Keep
//  it in sync with the web version and with real app behavior as
//  screens change, rather than letting it go stale.
//
import SwiftUI

private struct GuideSection: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let body: String
}

private let guideSections: [GuideSection] = [
    GuideSection(
        title: "How this app thinks",
        symbol: "checkmark.seal",
        body: """
        Everything you see here is a real, recorded number — a stat line from a game that already \
        happened, a line an actual sportsbook is offering right now, a rate computed from real recent \
        games. Nothing in this app is a made-up prediction, a win probability, or a confidence score.

        Where you'll see a "lean" (Over/Under/Toss-up on Props, a Signal on Rankings, a disagreement on \
        Edge), it's always a plain rule applied to real data — never a simulation or an invented \
        probability. If you're ever unsure whether a number is real or estimated, it's real; this app \
        doesn't estimate.
        """
    ),
    GuideSection(
        title: "Board",
        symbol: "square.grid.2x2",
        body: """
        The home tab — a curated snapshot of the current week rather than a full page of any one thing. \
        It pulls together this week's games, the strongest disagreements from Edge, a preview of the \
        Rankings leaders, and the Portfolio agent's live track record, so you can see the state of things \
        without visiting every tab.
        """
    ),
    GuideSection(
        title: "Games, Teams, Players",
        symbol: "magnifyingglass",
        body: """
        Games lists the schedule for any season and week — tap a game to see its own detail screen \
        (below). Teams browses every team by division; open one to see its full roster grouped by \
        position group. Players is search-and-filter across every player — open one to see their bio, \
        current injury status (if any), and season stats.
        """
    ),
    GuideSection(
        title: "Inside a game",
        symbol: "sportscourt",
        body: """
        Opening any game gets you the fullest view in the app: kickoff time and weather, both teams' \
        injury reports, the "Model vs. Market" read from Edge for this specific matchup, the full odds \
        board across every tracked bookmaker and market, both rosters' season stats, and — once the game \
        has kicked off — a live box score with top performers and a drive-by-drive Drive Feed. Not every \
        section has data for every game: the box score and drive feed only populate once a game is \
        actually underway or finished.
        """
    ),
    GuideSection(
        title: "Rankings",
        symbol: "chart.bar",
        body: """
        Players ranked within a stat category (passing yards, receptions, and others) by a deterministic \
        score built from real season data — recent form, matchup context, and a few other real signals \
        blended together. It's a ranking, not a prediction: the score reflects how a player has actually \
        been performing and who they're facing, not a projection of what they'll do next.
        """
    ),
    GuideSection(
        title: "Props",
        symbol: "list.bullet.rectangle",
        body: """
        This week's player prop lines from DraftKings — passing/rushing/receiving yards, receptions, and \
        anytime touchdown — each shown next to that player's real recent-form average (or, for \
        touchdowns, how often they've scored in their last 5 games). The Over/Under/Toss-up lean just \
        says how far that real average sits from the market's own line; it's a descriptive comparison, \
        not odds of winning. Once a game finishes, the card also shows what the player actually did that \
        game, graded against the locked-in line.
        """
    ),
    GuideSection(
        title: "Edge",
        symbol: "bolt.fill",
        body: """
        Compares this app's own model read (from Rankings' scoring) against what the betting market \
        itself is favoring — the actual spread and moneyline. When the two disagree, that's flagged as \
        an edge. When there isn't enough real signal on one or both sides to make a call, that's shown \
        plainly rather than forced into a guess.
        """
    ),
    GuideSection(
        title: "Portfolio",
        symbol: "briefcase",
        body: """
        The one screen in the app that writes something, rather than just showing you data. It builds a \
        slate of picks from this week's strongest edges. Preview slate shows you what it would pick \
        without saving anything; Build & log slate commits those picks to a real, permanent record — \
        which is exactly what shows up next on Picks and gets graded once those games finish.
        """
    ),
    GuideSection(
        title: "Picks & Leaderboard",
        symbol: "list.bullet.clipboard",
        body: """
        Picks is the Portfolio agent's full history — every pick it's ever logged, and how each one \
        graded once its game finished. Leaderboard ranks every agent that logs picks by real hit rate. \
        Right now that's a leaderboard of one, honestly — more rows show up as more agents start \
        picking, rather than being padded out artificially.
        """
    ),
    GuideSection(
        title: "Chat",
        symbol: "bubble.left.and.bubble.right",
        body: """
        Ask a real question in plain English — a player's stat line, a team's recent form — and get an \
        answer pulled from the same real data every other screen uses. It's a lookup tool with a \
        conversational front end, not a source of predictions or advice; if a question needs a \
        projection rather than a real number, it isn't something this app is built to answer.
        """
    ),
]

struct GuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("What every part of Chalk That NFL does, and how the pieces connect. Come back here any time — this screen doesn't move.")
                        .font(.brandBody(14))
                        .foregroundStyle(Color.inkDim)
                        .padding(.vertical, 4)
                }
                .listRowBackground(Color.surface)

                ForEach(guideSections) { section in
                    Section {
                        Text(section.body)
                            .font(.brandBody(14))
                            .foregroundStyle(Color.inkDim)
                            .lineSpacing(3)
                            .padding(.vertical, 4)
                    } header: {
                        Label(section.title, systemImage: section.symbol)
                            .font(.brandDisplay(13, weight: .semibold))
                            .foregroundStyle(Color.ink)
                            .textCase(nil)
                    }
                    .listRowBackground(Color.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .navigationTitle("Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    GuideView()
        .preferredColorScheme(.dark)
}
