//
//  DriveModels.swift
//  Chalk That NFL
//
//  Wire models for GET /games/:gameId/drives (backend/routes/games.js,
//  db/migrations/014_drive_events.sql) — drive-by-drive play-by-play,
//  one row per possession. `play_details` is the vendor's own
//  playDetails array stored verbatim as JSONB; DrivePlayDetail/
//  DrivePlayStart model only the fields the web app actually reads
//  (`p.text`, `p.start.down`, `p.start.distance`, `p.start.
//  possessionText` — DriveFeed() in GameDetailPage.jsx) rather than the
//  vendor's full per-play shape, since nothing else is displayed.
//
//  No NUMERIC columns anywhere in game_drives (drive_id is a plain
//  SERIAL/INT4, not BIGSERIAL — unlike picks_log.pick_id, this one
//  really does arrive as a JSON number) — so this whole file is plain
//  synthesized Decodable, no lenient decoding or custom init needed.
//
import Foundation

struct DrivePlayStart: Decodable, Hashable {
    let down: Int?
    let distance: Int?
    let possessionText: String?
}

struct DrivePlayDetail: Decodable, Hashable {
    let text: String?
    let start: DrivePlayStart?
}

struct GameDrive: Decodable, Identifiable, Hashable {
    let id: Int
    let teamId: Int
    let teamAbbr: String
    let driveSequence: Int
    /// Vendor's raw label, e.g. "1st Quarter" — stored as TEXT, not
    /// parsed into an int (see 014_drive_events.sql's own header on why).
    let startPeriod: String?
    let startClock: String?
    let startYardLine: Int?
    let endPeriod: String?
    let endClock: String?
    let endYardLine: Int?
    /// "Punt" | "Touchdown" | "Field Goal" | ...
    let result: String?
    /// e.g. "3 plays, 6 yards, 1:05"
    let description: String?
    let isScoringPlay: Bool
    let playDetails: [DrivePlayDetail]

    private enum CodingKeys: String, CodingKey {
        case id = "driveId"
        case teamId, teamAbbr, driveSequence, startPeriod, startClock, startYardLine
        case endPeriod, endClock, endYardLine, result, description, isScoringPlay, playDetails
    }
}

struct DriveFeedFreshness: Decodable {
    let syncedAt: String?
}

struct DriveFeedMeta: Decodable {
    /// Absent when `data` is null (the "game hasn't started yet" branch
    /// only returns `{reason}`) — same shape as BoxScoreMeta.
    let count: Int?
    let freshness: DriveFeedFreshness?
    let reason: String?
}

struct DriveFeedResponse: Decodable {
    let data: [GameDrive]?
    let meta: DriveFeedMeta
}
