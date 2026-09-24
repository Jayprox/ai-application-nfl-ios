//
//  AuthViewModel.swift
//  Chalk That NFL
//
//  Drives the login/logout flow and is the single source of truth for
//  `isAuthenticated`, which Chalk_That_NFLApp.swift uses to switch
//  between LoginView and MainTabView. Also listens for
//  .chalkThatNFLSessionExpired (posted by APIClient when a refresh
//  attempt fails) so a session that dies from an expired/rotated
//  refresh token anywhere in the app — not just on an explicit Log Out
//  tap — drops the person back to the login screen, same as web's
//  client.js.
//
import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var isAuthenticated: Bool
    @Published private(set) var username: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var sessionExpiredObserver: NSObjectProtocol?

    init() {
        // Access token may be a stale/expired 15-minute JWT by the time
        // the app relaunches — that's fine, the first authenticated
        // request will 401 and APIClient's refresh-and-retry handles it
        // transparently. Presence of a refresh token is what actually
        // means "there's a session to resume."
        isAuthenticated = KeychainManager.refreshToken != nil
        username = KeychainManager.username

        sessionExpiredObserver = NotificationCenter.default.addObserver(
            forName: .chalkThatNFLSessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isAuthenticated = false
            self?.username = nil
        }
    }

    deinit {
        if let sessionExpiredObserver {
            NotificationCenter.default.removeObserver(sessionExpiredObserver)
        }
    }

    func login(username: String, password: String) async {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your username and password."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let pair: TokenPairResponse = try await APIClient.shared.post(
                Endpoints.login,
                body: LoginRequest(username: trimmedUsername, password: password),
                authenticated: false
            )
            KeychainManager.saveSession(
                accessToken: pair.accessToken,
                refreshToken: pair.refreshToken,
                username: trimmedUsername
            )
            self.username = trimmedUsername
            isAuthenticated = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout() async {
        if let refreshToken = KeychainManager.refreshToken {
            // Best-effort — revokes the refresh token server-side so it
            // can't be replayed, but a local logout shouldn't hang or
            // fail on a network error.
            try? await APIClient.shared.postDiscardingResponse(
                Endpoints.logout,
                body: LogoutRequest(refreshToken: refreshToken),
                authenticated: false
            )
        }
        KeychainManager.clearSession()
        username = nil
        isAuthenticated = false
    }
}
