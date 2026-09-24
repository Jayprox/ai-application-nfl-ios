//
//  APIEnvelope.swift
//  Chalk That NFL
//
//  Almost every non-auth backend-api response is `{ data: ..., meta:
//  ... }` (see docs/architecture.md §4.5 in the backend-api repo). Meta
//  varies per route and isn't needed for the UI yet, so it's left
//  undeclared here — Decodable simply ignores keys a type doesn't ask
//  for, so this stays a one-line "just give me `data`" unwrap for every
//  GET/POST that follows this shape.
//
import Foundation

struct APIEnvelope<T: Decodable>: Decodable {
    let data: T
}
