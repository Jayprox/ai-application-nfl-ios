//
//  Font+Brand.swift
//  Chalk That NFL
//
//  Mirrors web's two-font system (frontend/src/index.css): Inter for
//  body/data (tables, badges, running text — the data-dense majority of
//  the UI) and Oswald for display (page titles, the brand wordmark,
//  hero stat numerals — the "scoreboard voice," used deliberately in a
//  few places, not everywhere).
//
//  NOTE: the actual Inter/Oswald .ttf files still need to be added to
//  this target (drag into Assets or a Fonts group, then list them under
//  Info.plist's "Fonts provided by application") before these calls
//  will resolve — until then SwiftUI silently falls back to the system
//  font. Flagging rather than silently shipping the wrong font.
//
import SwiftUI

extension Font {
    static func brandBody(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
    }

    static func brandDisplay(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("Oswald", size: size).weight(weight)
    }
}
