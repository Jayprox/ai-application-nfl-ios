//
//  GameModels.swift
//  Chalk That NFL
//
//  Wire models for backend/routes/games.js. Boxscore and season
//  player-stats shapes aren't modeled yet — deliberately deferred (see
//  HANDOFF.md) since they're a meaningfully separate chunk of work from
//  schedule/score/weather/injuries.
//
import Foundation

struct Game: Decodable, Identifiable, Hashable {
    var id: String { gameId }
    let gameId: String
    let season: Int
    let week: Int
    let gameType: String?
    let gameDatetime: String?
    let weatherCondition: String?
    /// NUMERIC column, no `::float8` cast in games.js — arrives as a
    /// JSON string ("72.5"), not a number. See Decoding+Lenient.swift.
    let weatherTempF: Double?
    /// Same NUMERIC-as-string situation as weatherTempF.
    let weatherWindMph: Double?
    /// SMALLINT, not NUMERIC — arrives as a real JSON number, but
    /// decoded leniently anyway for consistency/future-proofing.
    let weatherWindDirectionDeg: Double?
    let homeScore: Int?
    let awayScore: Int?
    /// "scheduled" | "in_progress" | "final" | "postponed"
    let status: String
    let gamePeriod: Int?
    let gameClock: String?
    let homeTeamId: Int
    let homeTeamAbbr: String
    let homeTeamName: String
    let awayTeamId: Int
    let awayTeamAbbr: String
    let awayTeamName: String
    let stadiumName: String?
    let stadiumCity: String?
    let stadiumState: String?
    let stadiumRoof: String?

    private enum CodingKeys: String, CodingKey {
        case gameId, season, week, gameType, gameDatetime
        case weatherCondition, weatherTempF, weatherWindMph, weatherWindDirectionDeg
        case homeScore, awayScore, status, gamePeriod, gameClock
        case homeTeamId, homeTeamAbbr, homeTeamName
        case awayTeamId, awayTeamAbbr, awayTeamName
        case stadiumName, stadiumCity, stadiumState, stadiumRoof
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameId = try container.decode(String.self, forKey: .gameId)
        season = try container.decode(Int.self, forKey: .season)
        week = try container.decode(Int.self, forKey: .week)
        gameType = try container.decodeIfPresent(String.self, forKey: .gameType)
        gameDatetime = try container.decodeIfPresent(String.self, forKey: .gameDatetime)
        weatherCondition = try container.decodeIfPresent(String.self, forKey: .weatherCondition)
        weatherTempF = try container.decodeLenientDoubleIfPresent(forKey: .weatherTempF)
        weatherWindMph = try container.decodeLenientDoubleIfPresent(forKey: .weatherWindMph)
        weatherWindDirectionDeg = try container.decodeLenientDoubleIfPresent(forKey: .weatherWindDirectionDeg)
        homeScore = try container.decodeIfPresent(Int.self, forKey: .homeScore)
        awayScore = try container.decodeIfPresent(Int.self, forKey: .awayScore)
        status = try container.decode(String.self, forKey: .status)
        gamePeriod = try container.decodeIfPresent(Int.self, forKey: .gamePeriod)
        gameClock = try container.decodeIfPresent(String.self, forKey: .gameClock)
        homeTeamId = try container.decode(Int.self, forKey: .homeTeamId)
        homeTeamAbbr = try container.decode(String.self, forKey: .homeTeamAbbr)
        homeTeamName = try container.decode(String.self, forKey: .homeTeamName)
        awayTeamId = try container.decode(Int.self, forKey: .awayTeamId)
        awayTeamAbbr = try container.decode(String.self, forKey: .awayTeamAbbr)
        awayTeamName = try container.decode(String.self, forKey: .awayTeamName)
        stadiumName = try container.decodeIfPresent(String.self, forKey: .stadiumName)
        stadiumCity = try container.decodeIfPresent(String.self, forKey: .stadiumCity)
        stadiumState = try container.decodeIfPresent(String.self, forKey: .stadiumState)
        stadiumRoof = try container.decodeIfPresent(String.self, forKey: .stadiumRoof)
    }

    var kickoffDate: Date? {
        BackendDate.parse(gameDatetime)
    }
}

struct CurrentWeek: Decodable {
    let season: Int
    let week: Int
}

struct InjuryReport: Decodable, Identifiable, Hashable {
    var id: String { playerId }
    let playerId: String
    let teamId: Int
    let fullName: String
    let position: String
    let reportStatus: String?
    let practiceStatus: String?
    let primaryInjury: String?
    let secondaryInjury: String?
    let reportDate: String?
}

struct GameInjuries: Decodable {
    let home: [InjuryReport]
    let away: [InjuryReport]
}
