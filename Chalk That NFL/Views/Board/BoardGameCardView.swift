//
//  BoardGameCardView.swift
//  Chalk That NFL
//
//  Board-only card: same content as Views/Games/GameRowView.swift (away
//  @ home, status, kickoff/stadium, score, weather) plus the Odds/Edge
//  badges GameRowView deliberately omits — mirrors GameCard.jsx, which
//  is shared by both GamesPage and BoardPage on web with the same
//  optional edge/odds props. Kept as its own view rather than adding
//  edge/odds params to GameRowView: GamesListView's full schedule
//  intentionally doesn't fetch edge/odds yet (see GamesViewModel's own
//  header comment — that's the Player Props+Odds / Rankings+Edge
//  phases), so this stays Board-specific until those phases land and
//  the two views can be reconsidered together.
//
//  The whole card navigates to GameDetailView (matches GameRowView's
//  precedent of not making team abbreviations separately tappable —
//  see that file), styled as a real card (background + corner radius)
//  since Board lays games out in a custom ScrollView/VStack, not a List.
//
import SwiftUI

struct BoardGameCardView: View {
    let game: Game
    let edge: EdgeRow?
    let odds: GameOdds?

    private var showScore: Bool { game.status == "final" || game.status == "in_progress" }

    private var kickoffLabel: String? {
        guard let date = game.kickoffDate else { return nil }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d, h:mm a")
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationLink(value: ResearchRoute.gameDetail(game.gameId)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(game.awayTeamAbbr)
                                .foregroundStyle(Color.link)
                            Text("@")
                                .foregroundStyle(Color.inkFaint)
                            Text(game.homeTeamAbbr)
                                .foregroundStyle(Color.link)
                            GameStatusBadge(status: game.status, period: game.gamePeriod, clock: game.gameClock)
                        }
                        .font(.brandBody(14, weight: .semibold))

                        Text([kickoffLabel, game.stadiumName].compactMap { $0 }.joined(separator: " · "))
                            .font(.brandBody(12))
                            .foregroundStyle(Color.inkDim)
                    }

                    Spacer()

                    if showScore {
                        Text("\(String(game.awayScore ?? 0))–\(String(game.homeScore ?? 0))")
                            .font(.brandBody(15, weight: .semibold))
                            .foregroundStyle(Color.ink)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        WeatherBadge(
                            condition: game.weatherCondition,
                            tempF: game.weatherTempF,
                            windMph: game.weatherWindMph,
                            windDirectionDeg: game.weatherWindDirectionDeg
                        )
                        OddsBadge(
                            odds: odds,
                            homeAbbr: game.homeTeamAbbr,
                            awayAbbr: game.awayTeamAbbr,
                            status: game.status,
                            homeScore: game.homeScore,
                            awayScore: game.awayScore
                        )
                        if let edge {
                            EdgeBadge(edge: edge.edge)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
