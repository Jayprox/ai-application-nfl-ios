//
//  APIClient.swift
//  Chalk That NFL
//
//  One central request wrapper — every API call goes through this,
//  never a raw URLSession call — mirroring web's single
//  frontend/src/api/client.js `apiFetch()` wrapper exactly (per the
//  build brief's §5): attaches the bearer token, and on a 401
//  transparently calls /refresh once (via TokenRefresher, which
//  dedupes concurrent refreshes) and retries the original request
//  exactly once. If the refresh itself fails, throws .unauthorized and
//  posts `.chalkThatNFLSessionExpired` so the UI can drop back to the
//  login screen — same as web's client.js.
//
import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int, String?)
    case decodingError(Error)
    case networkError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request."
        case .unauthorized:
            return "Session expired. Please log in again."
        case .serverError(let code, let message):
            return message ?? "Server error (\(code))."
        case .decodingError(let error):
            return "Couldn't read the server's response: \(error.localizedDescription)"
        case .networkError(let error):
            return error.localizedDescription
        case .unknown:
            return "Something went wrong."
        }
    }
}

extension Notification.Name {
    /// Posted whenever a request comes back unauthorized even after a
    /// refresh attempt — AuthViewModel observes this to flip
    /// isAuthenticated back to false from anywhere in the app, not just
    /// from an explicit "Log Out" tap.
    static let chalkThatNFLSessionExpired = Notification.Name("chalkThatNFLSessionExpired")
}

extension JSONDecoder {
    /// backend-api mixes casing: auth fields are camelCase
    /// (`accessToken`), but most data routes are snake_case
    /// (`entity_type`, `sample_size` — see docs/architecture.md §4.5 in
    /// the backend-api repo). `.convertFromSnakeCase` only rewrites keys
    /// that actually contain an underscore, so it's safe to apply
    /// globally and lets every Swift model stay idiomatic camelCase.
    static let chalkThatNFL: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

extension JSONEncoder {
    /// Symmetric with JSONDecoder.chalkThatNFL — e.g. POST /query's
    /// body (`entity_type`, `entity_id`) can be encoded from a
    /// camelCase Swift struct.
    static let chalkThatNFL: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let session = URLSession.shared

    /// - Parameters:
    ///   - retrying: internal — set true only on the one post-refresh
    ///     retry, so a still-401 response after a fresh token doesn't
    ///     loop forever.
    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        bodyData: Data? = nil,
        authenticated: Bool = true,
        retrying: Bool = false
    ) async throws -> T {
        guard let url = URL(string: Endpoints.baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated, let token = KeychainManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

        #if DEBUG
        print("[APIClient] \(method) \(path) -> \(http.statusCode), \(data.count) bytes")
        if let bodyPreview = String(data: data.prefix(500), encoding: .utf8) {
            print("[APIClient] body preview: \(bodyPreview)")
        }
        #endif

        switch http.statusCode {
        case 200...299:
            do {
                return try JSONDecoder.chalkThatNFL.decode(T.self, from: data)
            } catch {
                #if DEBUG
                print("[APIClient] decode failed for \(T.self): \(String(describing: error))")
                #endif
                throw APIError.decodingError(error)
            }

        case 401 where authenticated && !retrying:
            // Transparent refresh-and-retry-once, deduped across
            // concurrent callers by TokenRefresher.
            do {
                _ = try await TokenRefresher.shared.refreshedTokens()
            } catch {
                KeychainManager.clearSession()
                NotificationCenter.default.post(name: .chalkThatNFLSessionExpired, object: nil)
                throw APIError.unauthorized
            }
            return try await self.request(
                path: path,
                method: method,
                bodyData: bodyData,
                authenticated: authenticated,
                retrying: true
            )

        case 401:
            KeychainManager.clearSession()
            NotificationCenter.default.post(name: .chalkThatNFLSessionExpired, object: nil)
            throw APIError.unauthorized

        default:
            let apiMessage = try? JSONDecoder.chalkThatNFL.decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(http.statusCode, apiMessage?.error ?? apiMessage?.message)
        }
    }

    // MARK: - Convenience wrappers

    func get<T: Decodable>(_ path: String, authenticated: Bool = true) async throws -> T {
        try await request(path: path, method: "GET", authenticated: authenticated)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B, authenticated: Bool = true) async throws -> T {
        let data = try JSONEncoder.chalkThatNFL.encode(body)
        return try await request(path: path, method: "POST", bodyData: data, authenticated: authenticated)
    }

    /// For endpoints where the whole request is in the query string —
    /// e.g. POST /portfolio/slate (backend/routes/portfolio.js) — no
    /// JSON body at all, just a POST verb (chosen there because the
    /// non-dry-run call has a side effect) with plain query params.
    func post<T: Decodable>(_ path: String, authenticated: Bool = true) async throws -> T {
        try await request(path: path, method: "POST", authenticated: authenticated)
    }

    /// For endpoints that return `{ ok: true }`-style bodies you don't
    /// need to decode into anything meaningful, e.g. logout.
    func postDiscardingResponse<B: Encodable>(_ path: String, body: B, authenticated: Bool = true) async throws {
        let _: EmptyResponse = try await post(path, body: body, authenticated: authenticated)
    }
}

/// Decodes successfully against any JSON object body — used where we
/// only care that the call succeeded (2xx), not its payload shape.
struct EmptyResponse: Decodable {}
