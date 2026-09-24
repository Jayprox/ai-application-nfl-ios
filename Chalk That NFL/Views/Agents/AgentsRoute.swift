//
//  AgentsRoute.swift
//  Chalk That NFL
//
//  Every screen under the Agents tab shares ONE NavigationStack, rooted
//  in AgentsHomeView — same "one Hashable route type per tab" pattern
//  ResearchRoute already established for the Research tab. Props/
//  Rankings/Edge are real now (Portfolio/Chat are still ComingSoon rows
//  in AgentsHomeView — see HANDOFF.md's build order); their own cases
//  get added here as each one is built, same as ResearchRoute grew case
//  by case across the Games/Teams/Players phases.
//
import Foundation

enum AgentsRoute: Hashable {
    case props
    case rankings
    case edge
    case portfolio
    case chat
    case gameDetail(String)
    case playerDetail(String)
}
