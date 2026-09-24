//
//  RelativeTime.swift
//  Chalk That NFL
//
//  Mirrors PropsPage.jsx's formatSyncedAt() and RankingsPage.jsx's own
//  (differently-worded) copy of the same function — same coarse buckets
//  (just now / Nm ago / Nh ago / Nd ago) in both, but "synced" vs.
//  "computed" as the verb, matching what's actually true for each
//  route's freshness.synced_at (props.js/odds.js sync from a vendor;
//  rankings.js/matchup-score.js compute from data already ingested).
//  Shared bucket math here, verb-parameterized, rather than two copies
//  of the same Nm/Nh/Nd arithmetic.
//
//  GameDetailPage.jsx's OWN formatSyncedAt() (Live Box Score / Drive
//  Feed sections, 2026-09-20/21 phase) is a genuinely different
//  function despite the identical name — it renders an absolute
//  wall-clock time (`toLocaleTimeString('en-US', {hour:'numeric',
//  minute:'2-digit'})`, e.g. "3:45 PM"), not a relative bucket, because
//  those two sections' own copy reads "Box score as of {label}" /
//  "Drives as of {label}" rather than "synced Nm ago" — clockTimeLabel
//  below matches that, kept alongside sinceSynced/sinceComputed since
//  it's the same "format this freshness.synced_at ISO string" job.
//
import Foundation

enum RelativeTime {
    static func sinceSynced(_ iso: String?) -> String {
        since(iso, verb: "synced", neverLabel: "not yet synced")
    }

    static func sinceComputed(_ iso: String?) -> String {
        since(iso, verb: "computed", neverLabel: "not yet computed")
    }

    /// Matches GameDetailPage.jsx's own formatSyncedAt(freshness) —
    /// returns nil when there's no synced_at yet (the caller only shows
    /// the "as of ..." line when this is non-nil, same as web's `{label
    /// && <p>...}` guard).
    static func clockTimeLabel(_ iso: String?) -> String? {
        guard let date = BackendDate.parse(iso) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func since(_ iso: String?, verb: String, neverLabel: String) -> String {
        guard let iso, let date = BackendDate.parse(iso) else { return neverLabel }
        let diffMinutes = Int((Date().timeIntervalSince(date) / 60).rounded())
        if diffMinutes < 1 { return "\(verb) just now" }
        if diffMinutes < 60 { return "\(verb) \(diffMinutes)m ago" }
        let diffHours = Int((Double(diffMinutes) / 60).rounded())
        if diffHours < 24 { return "\(verb) \(diffHours)h ago" }
        let diffDays = Int((Double(diffHours) / 24).rounded())
        return "\(verb) \(diffDays)d ago"
    }
}
