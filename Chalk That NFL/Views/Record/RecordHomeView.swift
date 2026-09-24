//
//  RecordHomeView.swift
//  Chalk That NFL
//
//  Root of the Record tab — Picks / Leaderboard, matching web's own
//  "Record" nav group (frontend/src/components/Layout.jsx's
//  RECORD_ITEMS) in the same order. Both are real now — this replaces
//  MainTabView's Record ComingSoonView placeholder (see HANDOFF.md's
//  build order: Portfolio/Picks/Leaderboard is the phase that lands
//  both this and PortfolioView under Agents at the same time).
//
import SwiftUI

struct RecordHomeView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink(value: RecordRoute.picks) {
                    Label("Picks", systemImage: "checkmark.seal")
                }
                NavigationLink(value: RecordRoute.leaderboard) {
                    Label("Leaderboard", systemImage: "trophy")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .navigationTitle("Record")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { AccountMenuButton() }
            }
            .navigationDestination(for: RecordRoute.self) { route in
                switch route {
                case .picks:
                    PicksView()
                case .leaderboard:
                    LeaderboardView()
                }
            }
        }
    }
}
