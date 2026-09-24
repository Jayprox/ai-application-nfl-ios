//
//  Decoding+Lenient.swift
//  Chalk That NFL
//
//  Postgres NUMERIC/DECIMAL columns come back from the `pg` driver as
//  JSON STRINGS (e.g. "72.5"), not JSON numbers — that's `pg`'s default
//  behavior for NUMERIC, to avoid silent float-precision loss; backend-
//  api's db.js registers no custom type parser to change that. A column
//  the SQL explicitly casts with `::float8` (e.g. the season-stats
//  AVG/SUM columns in games.js's player-stats route) DOES arrive as a
//  real JSON number, since that cast happens before Postgres hands the
//  row to `pg`. So the same logical field can be either shape depending
//  on the query, and a Swift model shouldn't have to know which —
//  hence this lenient decode helper instead of assuming `Double`.
//
//  First hit: GET /games's weather_temp_f / weather_wind_mph (real
//  NUMERIC columns, no cast) decoding into `Double?` threw a
//  typeMismatch — "Couldn't be read because it isn't in the correct
//  format." Expect the same shape (string-encoded numbers) from odds
//  prices / prop lines in later phases; use this helper there too
//  rather than re-diagnosing the same bug.
//
import Foundation

extension KeyedDecodingContainer {
    func decodeLenientDoubleIfPresent(forKey key: K) throws -> Double? {
        if let doubleValue = ((try? decodeIfPresent(Double.self, forKey: key)) ?? nil) {
            return doubleValue
        }
        if let stringValue = ((try? decodeIfPresent(String.self, forKey: key)) ?? nil) {
            return Double(stringValue)
        }
        return nil
    }

    func decodeLenientDouble(forKey key: K) throws -> Double {
        if let value = try decodeLenientDoubleIfPresent(forKey: key) {
            return value
        }
        throw DecodingError.valueNotFound(
            Double.self,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Double or numeric String for key \(key.stringValue)")
        )
    }
}
