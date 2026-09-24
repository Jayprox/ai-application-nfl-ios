//
//  Chalk_That_NFLApp.swift
//  Chalk That NFL
//
//  Entry point. Routes Login vs. the main tab shell off
//  AuthViewModel.isAuthenticated — same shape as the Chalk That MLB
//  iOS app's own App.swift.
//
import SwiftUI

@main
struct Chalk_That_NFLApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(auth)
            .preferredColorScheme(.dark) // Stadium Lights is the only theme — no light mode.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
}
