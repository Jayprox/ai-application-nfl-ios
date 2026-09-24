//
//  TokenRefresher.swift
//  Chalk That NFL
//
//  Deduplicates concurrent token refreshes. Mirrors web's
//  frontend/src/api/client.js exactly: "concurrent 401s share a single
//  in-flight refresh call rather than each firing their own" — called
//  out in the build brief as a deliberate fix, not an oversight, so
//  it's reproduced deliberately here too, not just "add a refresh
//  call" in the naive/racy way.
//
//  An `actor` gives this for free: only one call to refreshedTokens()
//  runs its body at a time, so the "is a refresh already in flight"
//  check-then-set can't race the way it could on a plain class.
//
import Foundation

actor TokenRefresher {
    static let shared = TokenRefresher()
    private init() {}

    private var inFlightRefresh: Task<TokenPairResponse, Error>?

    /// Returns the new token pair, refreshing at most once even if many
    /// callers arrive while a refresh is already underway. Throws (and
    /// leaves the Keychain cleared) if the refresh token itself is
    /// invalid/expired/already-rotated — backend-api revokes the whole
    /// session on refresh-token replay (docs/architecture.md §4.7), so
    /// there's no partial-recovery path; the caller drops to login.
    func refreshedTokens() async throws -> TokenPairResponse {
        if let existing = inFlightRefresh {
            return try await existing.value
        }

        let task = Task<TokenPairResponse, Error> {
            try await Self.performRefresh()
        }
        inFlightRefresh = task

        do {
            let result = try await task.value
            inFlightRefresh = nil
            return result
        } catch {
            inFlightRefresh = nil
            throw error
        }
    }

    /// Not routed through APIClient.request — that method is what calls
    /// *this* on a 401, so going back through it would recurse.
    private static func performRefresh() async throws -> TokenPairResponse {
        guard let refreshToken = KeychainManager.refreshToken else {
            throw APIError.unauthorized
        }

        guard let url = URL(string: Endpoints.baseURL + Endpoints.refresh) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.chalkThatNFL.encode(RefreshRequest(refreshToken: refreshToken))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        guard (200...299).contains(http.statusCode) else {
            KeychainManager.clearSession()
            throw APIError.unauthorized
        }

        let pair = try JSONDecoder.chalkThatNFL.decode(TokenPairResponse.self, from: data)
        KeychainManager.accessToken = pair.accessToken
        KeychainManager.refreshToken = pair.refreshToken
        return pair
    }
}
