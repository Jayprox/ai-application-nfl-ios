//
//  GameDriveFeedSection.swift
//  Chalk That NFL
//
//  Mirrors GameDetailPage.jsx's "Drive Feed" section (2026-09-20, Part 2
//  backlog item 2) — GET /games/:id/drives rendered most-recent-drive-
//  first (DriveFeed()'s own `[...drives].reverse()`), each with its
//  play_details list rendered as-is. down/distance/possessionText come
//  straight off the vendor's own playDetails[].start object — same
//  "translation, not computation" rule as the rest of this app, nothing
//  here is derived or estimated.
//
//  The section header ("Drive Feed") always renders; the empty-state
//  copy branches on game.status exactly like Live Box Score's:
//  "Drive feed available once the game kicks off." while scheduled,
//  "No drives synced yet for this game." otherwise (matching web's
//  `drives.length === 0 ? <p>{status==='scheduled' ? ... : ...}</p> :
//  <div>...</div>`).
//
//  Footer text ("Drives as of {clock time}[— updates...]") only renders
//  when freshness.synced_at is present, matching web's own
//  `{drivesSyncedAtLabel && <p>...}` guard — an absolute wall-clock time
//  (RelativeTime.clockTimeLabel), not a relative bucket — see
//  GameBoxScoreSection.swift's identical footer for the same reasoning.
//
import SwiftUI

enum GameDriveFeedDisplay {
    /// Matches web's ordinalDown(n): {1:'1st',2:'2nd',3:'3rd',4:'4th'},
    /// else "${n}th".
    static func ordinalDown(_ n: Int?) -> String? {
        guard let n else { return nil }
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        case 4: return "4th"
        default: return "\(n)th"
        }
    }
}

struct GameDriveFeedSection: View {
    let game: Game
    let drives: [GameDrive]
    let syncedAt: String?

    /// Most-recent-drive-first — matches web's `[...drives].reverse()`.
    private var ordered: [GameDrive] {
        Array(drives.reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drive Feed")
                .font(.brandBody(13, weight: .semibold))
                .foregroundStyle(Color.inkFaint)
                .textCase(.uppercase)

            if drives.isEmpty {
                Text(game.status == "scheduled"
                     ? "Drive feed available once the game kicks off."
                     : "No drives synced yet for this game.")
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(ordered) { drive in
                        driveCard(drive)
                    }
                }

                if let label = RelativeTime.clockTimeLabel(syncedAt) {
                    Text("Drives as of \(label)" +
                        (game.status == "in_progress" ? " — updates every few minutes while the game is live." : ""))
                        .font(.brandBody(11))
                        .foregroundStyle(Color.inkFaint)
                }
            }
        }
    }

    private func driveCard(_ drive: GameDrive) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text("\(drive.teamAbbr) drive")
                    .font(.brandBody(13, weight: .medium))
                    .foregroundStyle(Color.ink)
                Spacer(minLength: 8)
                Text(resultLine(drive))
                    .font(.brandBody(12))
                    .foregroundStyle(Color.inkDim)
                    .multilineTextAlignment(.trailing)
            }

            Text(metaLine(drive))
                .font(.brandBody(11))
                .foregroundStyle(Color.inkFaint)

            if !drive.playDetails.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(drive.playDetails.enumerated()), id: \.offset) { _, play in
                        playLine(play)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(drive.isScoringPlay ? Color.positive.opacity(0.05) : Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(drive.isScoringPlay ? Color.positive.opacity(0.5) : Color.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// "{result ?? 'In progress'}{ · {description} if present}"
    private func resultLine(_ drive: GameDrive) -> String {
        var text = drive.result ?? "In progress"
        if let description = drive.description, !description.isEmpty {
            text += " · \(description)"
        }
        return text
    }

    /// "{startPeriod} {startClock}{ · started at {startYardLine}}{ → ended at {endYardLine}}"
    private func metaLine(_ drive: GameDrive) -> String {
        let parts = [drive.startPeriod, drive.startClock].compactMap { $0 }.filter { !$0.isEmpty }
        var text = parts.joined(separator: " ")
        if let start = drive.startYardLine {
            text += " · started at \(start)"
        }
        if let end = drive.endYardLine {
            text += " → ended at \(end)"
        }
        return text
    }

    private func playLine(_ play: DrivePlayDetail) -> some View {
        // NOTE: Text.foregroundStyle(_:) (the per-run-style overload that
        // keeps returning `Text` so `+` concatenation still works) is
        // iOS 17+ only -- min deployment target here is iOS 16, so this
        // uses the older Text.foregroundColor(_:) instead, which has
        // always returned `Text` and is available since iOS 13. Found
        // via Xcode's real build error (2026-09-21): "'foregroundStyle'
        // is only available in iOS 17.0 or newer" on this exact line --
        // the shell-only balance checker can't catch an availability
        // error like this, only a real build can.
        var text = Text("")
        if let down = play.start?.down {
            let ordinal = GameDriveFeedDisplay.ordinalDown(down) ?? "\(down)th"
            let distance = play.start?.distance.map(String.init) ?? "—"
            let possession = play.start?.possessionText ?? ""
            text = Text("\(ordinal) & \(distance) at \(possession) — ")
                .foregroundColor(Color.inkFaint)
        }
        return (text + Text(play.text ?? ""))
            .font(.brandBody(11))
            .foregroundColor(Color.inkDim)
    }
}
