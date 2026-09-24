//
//  GameRowView.swift
//  Chalk That NFL
//
//  Mirrors GameCard.jsx's content (minus the Edge/Odds badges, which
//  belong to a later build phase — see HANDOFF.md): away @ home with a
//  status pill, kickoff time + stadium, score once live/final, weather.
//
import SwiftUI

struct GameRowView: View {
    let game: Game

    private var showScore: Bool { game.status == "final" || game.status == "in_progress" }

    private var kickoffLabel: String? {
        guard let date = game.kickoffDate else { return nil }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d, h:mm a")
        return formatter.string(from: date)
    }

    var body: some View {
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

            WeatherBadge(
                condition: game.weatherCondition,
                tempF: game.weatherTempF,
                windMph: game.weatherWindMph,
                windDirectionDeg: game.weatherWindDirectionDeg
            )
        }
        .padding(.vertical, 6)
    }
}
