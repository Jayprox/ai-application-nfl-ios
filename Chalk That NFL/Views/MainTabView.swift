//
//  MainTabView.swift
//  Chalk That NFL
//
//  Tab shape mirrors web's own IA (frontend/src/components/Layout.jsx +
//  NavGroup.jsx in the backend-api repo), not the MLB app's flat
//  per-feature tabs — MLB's tabs are one-tab-per-feature with no
//  grouping, but web here already groups its 9 non-Board routes into 3
//  clusters (Research / Agents / Record) with Board standalone as the
//  front door, so that's the shape worth mirroring for "match the web
//  app as closely as iOS conventions allow." Each tab is a
//  NavigationStack; sub-screens push within their own tab as they're
//  built, same as web's grouped dropdown links to a flat set of routes.
//
//  Research, Board, Agents, and Record are all wired to real data now
//  (Agents' own "Coming soon" row covers Chat, the one phase left — see
//  HANDOFF.md's build order).
//
//  Board gets its own NavigationStack + `.navigationDestination(for:
//  ResearchRoute.self)` (same route enum ResearchHomeView uses, same
//  switch cases) rather than sharing Research's stack — each tab is an
//  independent navigation flow in a TabView, so "Full schedule"/game/
//  team/player pushes from Board land on Board's own stack, separate
//  from whatever's pushed under Research. Two stacks pushing the same
//  destination types is a normal SwiftUI pattern, not a conflict.
//
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                BoardView()
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
            .tabItem { Label("Board", systemImage: "square.grid.2x2") }

            ResearchHomeView()
                .tabItem { Label("Research", systemImage: "magnifyingglass") }

            AgentsHomeView()
                .tabItem { Label("Agents", systemImage: "sparkles") }

            RecordHomeView()
                .tabItem { Label("Record", systemImage: "list.bullet.clipboard") }
        }
        .tint(Color.accent)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
