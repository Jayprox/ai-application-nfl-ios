//
//  ChatView.swift
//  Chalk That NFL
//
//  Mirrors ChatPage.jsx: a welcome line until the first message, a
//  scrolling bubble list (user bubbles right/accent, assistant bubbles
//  left/surface2, assistant content run through ChatMarkdown), a
//  "Thinking…" line while a reply is in flight, and a text field + Send
//  button pinned to the bottom. Pushed onto Agents' shared
//  NavigationStack (see AgentsRoute.swift) — this is the last of the
//  five agent tabs web groups together.
//
import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Text(
                "The research assistant \u{2014} calls the same rankings, edge, insights, picks, and leaderboard " +
                "data as the other tabs, answers only from what those return."
            )
            .font(.brandBody(13))
            .foregroundStyle(Color.inkDim)
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.canvas)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if viewModel.messages.isEmpty {
                            Text(ChatViewModel.welcomeMessage)
                                .font(.brandBody(13))
                                .foregroundStyle(Color.inkFaint)
                        }
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }
                        if viewModel.isSending {
                            Text("Thinking\u{2026}")
                                .font(.brandBody(13))
                                .foregroundStyle(Color.inkFaint)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.surface)
                .onChange(of: viewModel.messages) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: viewModel.isSending) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.brandBody(13))
                    .foregroundStyle(Color.negative)
                    .padding(.horizontal)
                    .padding(.top, 6)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("e.g. Who are the top rushing matchups this week?", text: $viewModel.input, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await viewModel.send() } }

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Text("Send")
                        .font(.brandBody(14, weight: .medium))
                        .foregroundStyle(Color.onAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .disabled(!viewModel.canSend)
                .opacity(viewModel.canSend ? 1 : 0.4)
            }
            .padding()
            .background(Color.canvas)
        }
        .background(Color.canvas)
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            Group {
                if message.role == .assistant {
                    ChatMarkdownView(content: message.content)
                } else {
                    Text(message.content)
                }
            }
            .font(.brandBody(14))
            .foregroundStyle(message.role == .user ? Color.onAccent : Color.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(message.role == .user ? Color.accent : Color.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}
