//
//  AuthModels.swift
//  Chalk That NFL
//
//  Wire models for backend-api's auth routes (backend/routes/auth.js).
//  Username + password, not email — matches the existing Chalk That
//  convention (see that file's own auth note); there's no signup route,
//  accounts are created server-side.
//
import Foundation

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct RefreshRequest: Encodable {
    let refreshToken: String
}

struct LogoutRequest: Encodable {
    let refreshToken: String
}

/// POST /login and POST /refresh both return this same shape:
/// `{ accessToken, refreshToken }`.
struct TokenPairResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

/// backend-api's error responses are `{ error: "..." }`, occasionally
/// with a second `message` field (e.g. routes/admin.js) — surface
/// whichever is present.
struct APIErrorResponse: Decodable {
    let error: String?
    let message: String?
}
