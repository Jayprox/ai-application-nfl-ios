//
//  ResearchRoute.swift
//  Chalk That NFL
//
//  Every screen under the Research tab (Games/Teams/Players and their
//  detail pushes) shares ONE NavigationStack, rooted in
//  ResearchHomeView — so this single Hashable route type is what all of
//  them push through, rather than each screen declaring its own nested
//  NavigationStack (which SwiftUI doesn't handle well) or several
//  ambiguous `navigationDestination(for: String.self)` registrations
//  colliding on type (game ids and player ids are both String).
//
import Foundation

enum ResearchRoute: Hashable {
    case games
    case teams
    case players
    case gameDetail(String)
    case teamDetail(Int)
    case playerDetail(String)
}
