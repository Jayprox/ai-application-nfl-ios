//
//  KeyedGroup.swift
//  Chalk That NFL
//
//  A named group of items (a division's teams, a roster bucket's
//  players) for sectioned Lists. Using a real Identifiable struct here
//  rather than a labeled tuple + `id: \.label` — keypaths into tuple
//  labels are unreliable across Swift versions, and this is guaranteed
//  to compile.
//
struct KeyedGroup<Item>: Identifiable {
    let id: String
    let items: [Item]
}
