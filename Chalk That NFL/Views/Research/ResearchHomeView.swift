//
//  ResearchHomeView.swift
//  Chalk That NFL
//
//  Root of the Research tab — Games / Teams / Players, matching web's
//  own "Research" nav group (frontend/src/components/Layout.jsx).
//
import SwiftUI

struct ResearchHomeView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink(value: ResearchRoute.games) {
                    Label("Games", systemImage: "sportscourt")
                }
                NavigationLink(value: ResearchRoute.teams) {
                    Label("Teams", systemImage: "shield.lefthalf.filled")
                }
                NavigationLink(value: ResearchRoute.players) {
                    Label("Players", systemImage: "person.3")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .navigationTitle("Research")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { AccountMenuButton() }
            }
            .navigationDestination(for: ResearchRoute.self) { route in
                switch route {
                case .games:
                    GamesListView()
                case .teams:
                    TeamsListView()
                case .players:
                    PlayersListView()
                case .gameDetail(let gameId):
                    GameDetailView(gameId: gameId)
                case .teamDetail(let teamId):
                    TeamDetailView(teamId: teamId)
                case .playerDetail(let playerId):
                    PlayerDetailView(playerId: playerId)
                }
            }
        }
    }
}
