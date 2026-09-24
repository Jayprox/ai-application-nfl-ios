//
//  Color+Brand.swift
//  Chalk That NFL
//
//  Single source of truth for design tokens — the native-Swift
//  equivalent of frontend/src/index.css's `@theme` block in the
//  backend-api repo's `web` app ("Stadium Lights", the app's one and
//  only dark theme — there is no light mode to mirror).
//
//  Rule: no hardcoded hex values anywhere else in the app. Every color
//  used in a View comes from one of these tokens, same discipline the
//  Chalk That MLB iOS app's own Color+Brand.swift follows for its
//  palette.
//
//  Keep this file in sync with web's index.css by hand — there's no
//  build-time link between the two repos.
//

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // MARK: - Surfaces
    static let canvas    = Color(hex: "#0b0f14")  // page background
    static let surface   = Color(hex: "#121820")  // card/header/table/panel background
    static let surface2  = Color(hex: "#1a222c")  // hover fill, neutral chip background
    static let line      = Color(hex: "#2a3540")  // borders, dividers, form-control borders

    // MARK: - Text
    static let ink       = Color(hex: "#f5f7fa")  // primary text
    static let inkDim    = Color(hex: "#9aa7b4")  // secondary text, descriptions
    static let inkFaint  = Color(hex: "#62717d")  // muted/meta text, table header labels

    // MARK: - Brand / interactive
    static let link      = Color(hex: "#4d9fec")  // inline navigational links (stadium-light blue)
    // NOTE: no `static let accent` here on purpose — Assets.xcassets'
    // AccentColor.colorset is already set to #f4762b (the "end-zone
    // orange"), and ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_
    // EXTENSIONS (on for this target) auto-generates `Color.accent`
    // from it. Declaring our own `static let accent` here collided with
    // that generated symbol ("Invalid redeclaration of 'accent'") — if
    // you ever need to change the accent color, edit the colorset in
    // Assets.xcassets, not this file.
    static let onAccent  = Color(hex: "#0b0f14")  // text/icons sitting on the accent color

    // MARK: - Semantic
    static let caution   = Color(hex: "#e8b64a")  // mild warning — ties/pushes, questionable
    static let positive  = Color(hex: "#34d399")  // success / agree / favorable (over, scored, hit)
    static let negative  = Color(hex: "#f2545b")  // error / disagree (under, no-TD, miss)
}
