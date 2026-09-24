//
//  AgentsHomeView.swift
//  Chalk That NFL
//
//  Root of the Agents tab — Rankings / Props / Edge / Portfolio / Chat,
//  matching web's own "Agents" nav group (frontend/src/components/
//  Layout.jsx's AGENTS_ITEMS) in the same order. All five are real now
//  — this is the last screen in HANDOFF.md's build order.
//
import SwiftUI

struct AgentsHomeView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink(value: AgentsRoute.rankings) {
                    Label("Rankings", systemImage: "chart.bar")
                }
                NavigationLink(value: AgentsRoute.props) {
                    Label("Props", systemImage: "list.bullet.rectangle")
                }
                NavigationLink(value: AgentsRoute.edge) {
                    Label("Edge", systemImage: "bolt.fill")
                }
                NavigationLink(value: AgentsRoute.portfolio) {
                    Label("Portfolio", systemImage: "briefcase")
                }
                NavigationLink(value: AgentsRoute.chat) {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .navigationTitle("Agents")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { AccountMenuButton() }
            }
            .navigationDestination(for: AgentsRoute.self) { route in
                switch route {
                case .rankings:
                    RankingsView()
                case .props:
                    PropsView()
                case .edge:
                    EdgeView()
                case .portfolio:
                    PortfolioView()
                case .chat:
                    ChatView()
                case .gameDetail(let gameId):
                    GameDetailView(gameId: gameId)
                case .playerDetail(let playerId):
                    PlayerDetailView(playerId: playerId)
                }
            }
        }
    }
}
