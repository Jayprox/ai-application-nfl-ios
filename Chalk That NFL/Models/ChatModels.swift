//
//  ChatModels.swift
//  Chalk That NFL
//
//  Wire models for backend/routes/chat.js — POST /chat, { messages:
//  [{role, content}] } -> { data: { role: "assistant", content } }.
//  Stateless: the whole visible conversation is resent every message
//  (matching ChatPage.jsx's own client-side design — no server-side
//  session state in v1), so ChatWireMessage/ChatRequest exist purely
//  for that request/response shape. ChatMessage (below) is the
//  UI-facing model the View actually renders — kept separate so the
//  view layer doesn't need to know about the wire shape at all, same
//  "wire model vs. UI model" split PropRow/PropCardView already draw.
//
import Foundation

/// Plain Decodable/Encodable — no lenient decoding needed anywhere in
/// this file; `role`/`content` are always plain strings, never a
/// NUMERIC column.
struct ChatWireMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Encodable {
    let messages: [ChatWireMessage]
}

enum ChatRole: String {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: ChatRole
    let content: String
}
