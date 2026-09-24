//
//  ChatViewModel.swift
//  Chalk That NFL
//
//  Mirrors ChatPage.jsx exactly, including its one quirk worth calling
//  out: sending a message trims the VISIBLE conversation itself to the
//  last MAX_HISTORY entries (not just what's sent to the server) —
//  `setMessages(next)` where `next` is already `.slice(-MAX_HISTORY)` —
//  but the assistant's reply is then appended WITHOUT re-trimming, so
//  the count can briefly sit one over MAX_HISTORY until the next send.
//  Ported as-is rather than "fixed", since this is a direct visual/
//  behavioral mirror of the web app, not a bug to quietly improve on.
//
//  No new persistence here either — same as web, the conversation lives
//  only in this view model's state and is gone once the tab is backed
//  out of or the app relaunches.
//
import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    static let maxHistory = 12
    static let welcomeMessage =
        "Ask about matchup rankings, model-vs-market edges, player insights, or how the agents are grading out — " +
        "I only answer from real computed data, and I can't generate or log a pick myself (that's the Picks tab)."

    @Published var input: String = ""
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?

    var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        var next = messages
        next.append(ChatMessage(role: .user, content: text))
        if next.count > Self.maxHistory {
            next.removeFirst(next.count - Self.maxHistory)
        }
        messages = next
        input = ""
        errorMessage = nil
        isSending = true

        let wireMessages = next.map { ChatWireMessage(role: $0.role.rawValue, content: $0.content) }
        do {
            let envelope: APIEnvelope<ChatWireMessage> = try await APIClient.shared.post(
                Endpoints.chat,
                body: ChatRequest(messages: wireMessages)
            )
            let reply = envelope.data
            messages.append(ChatMessage(role: ChatRole(rawValue: reply.role) ?? .assistant, content: reply.content))
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}
