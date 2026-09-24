//
//  BackendDate.swift
//  Chalk That NFL
//
//  Centralized ISO8601 parsing for backend-api's TIMESTAMPTZ columns.
//  Node's `Date.prototype.toJSON()` (what `res.json()` uses under the
//  hood to serialize a JS Date) always includes milliseconds, e.g.
//  "2026-09-21T17:00:00.000Z" — but `ISO8601DateFormatter()`'s default
//  format options ([.withInternetDateTime]) don't parse fractional
//  seconds and silently return nil for every such timestamp.
//
//  Found via Game.kickoffDate always returning nil (Board's "Date TBD"
//  bug, 2026-09-20 verification pass) and the identical issue in
//  OddsBadgeLogic.latestDK()'s synced_at comparison. Centralized here
//  instead of a third copy of the same two-formatter dance for Props'
//  own synced_at/bookmaker_last_update fields.
//
import Foundation

enum BackendDate {
    private static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Fallback for the (currently theoretical) case of a timestamp
    /// without milliseconds — kept for defensiveness, same spirit as
    /// the two-formatter fallback this replaces.
    private static let standard = ISO8601DateFormatter()

    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        return withFractionalSeconds.date(from: value) ?? standard.date(from: value)
    }
}
