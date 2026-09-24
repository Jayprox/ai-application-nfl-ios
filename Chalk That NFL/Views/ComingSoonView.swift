//
//  ComingSoonView.swift
//  Chalk That NFL
//
//  Placeholder root for a nav group's screens before they're built —
//  temporary scaffolding for the tab shell, not a real screen. Each tab
//  gets its own so the app is navigable end-to-end (including logging
//  out) before Games/Props/etc. land per the build order in HANDOFF.md.
//
import SwiftUI

struct ComingSoonView: View {
    let title: String
    let symbol: String
    let items: [String]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: symbol)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.inkFaint)
                Text("\(title) is coming next")
                    .font(.brandBody(17, weight: .semibold))
                    .foregroundStyle(Color.ink)
                if !items.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(items, id: \.self) { item in
                            Text(item)
                                .font(.brandBody(14))
                                .foregroundStyle(Color.inkDim)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.canvas)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AccountMenuButton()
                }
            }
        }
    }
}

/// Shared account/log-out control, shown on every tab's root — there's
/// no dedicated Settings screen yet, and every tab should still be able
/// to sign out (mirrors web's Layout.jsx, which puts "Log out" in the
/// always-visible header rather than nesting it under a group).
struct AccountMenuButton: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var showingConfirmation = false
    @State private var showingGuide = false

    var body: some View {
        Menu {
            if let username = auth.username {
                Text("Signed in as \(username)")
            }
            Button {
                showingGuide = true
            } label: {
                Label("Guide", systemImage: "book")
            }
            Button("Log Out", role: .destructive) {
                showingConfirmation = true
            }
        } label: {
            Image(systemName: "person.crop.circle")
                .foregroundStyle(Color.ink)
        }
        .confirmationDialog(
            "Log out of Chalk That NFL?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive) {
                Task { await auth.logout() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingGuide) {
            GuideView()
        }
    }
}
