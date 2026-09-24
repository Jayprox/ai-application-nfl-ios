//
//  KeychainManager.swift
//  Chalk That NFL
//
//  iOS Keychain storage for the access/refresh token pair — the
//  native-appropriate equivalent of what web does with localStorage
//  (backend-api's auth is short-lived JWT access token + rotating
//  refresh token; see docs/architecture.md §2 "two-tier auth" in the
//  backend-api repo). Also stores the username the person logged in
//  with, purely for local display (Settings/Account row, "log out"
//  confirmation) — backend-api has no GET /me-style route to fetch it
//  back (unlike the MLB sister app's backend), so this is the one
//  client-side value that isn't a mirror of a server response, just a
//  local echo of what the person typed at login.
//
import Foundation
import Security

enum KeychainManager {
    private static let service = "com.chalkthat.nfl"
    private static let accessTokenKey  = "chalkThatNFL_accessToken"
    private static let refreshTokenKey = "chalkThatNFL_refreshToken"
    private static let usernameKey     = "chalkThatNFL_username"

    // MARK: - Generic get/set/delete over kSecClassGenericPassword

    @discardableResult
    private static func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(forKey: key) // remove any existing entry first — avoids duplicate-item error
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private static func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    @discardableResult
    private static func delete(forKey key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    // MARK: - Token pair

    static var accessToken: String? {
        get { load(forKey: accessTokenKey) }
        set {
            if let newValue { save(newValue, forKey: accessTokenKey) }
            else { delete(forKey: accessTokenKey) }
        }
    }

    static var refreshToken: String? {
        get { load(forKey: refreshTokenKey) }
        set {
            if let newValue { save(newValue, forKey: refreshTokenKey) }
            else { delete(forKey: refreshTokenKey) }
        }
    }

    static var username: String? {
        get { load(forKey: usernameKey) }
        set {
            if let newValue { save(newValue, forKey: usernameKey) }
            else { delete(forKey: usernameKey) }
        }
    }

    static func saveSession(accessToken: String, refreshToken: String, username: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        if let username { self.username = username }
    }

    /// Clears the whole session — called on logout, and on any refresh
    /// failure (backend-api's refresh-token rotation means a reused or
    /// expired refresh token can't be recovered from; the only correct
    /// move is to drop back to the login screen, same as web's client.js).
    static func clearSession() {
        accessToken = nil
        refreshToken = nil
        username = nil
    }
}
