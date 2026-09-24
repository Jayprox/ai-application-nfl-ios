//
//  AsyncStateView.swift
//  Chalk That NFL
//
//  Native equivalent of frontend/src/components/AsyncState.jsx — dumb on
//  purpose, no data-shape awareness, so it works the same for every
//  screen. Renders nothing once content has loaded; the caller shows its
//  own content view in that case.
//
import SwiftUI

struct AsyncStateView: View {
    let loading: Bool
    let error: String?
    var loadingLabel: String = "Loading…"
    var onRetry: (() -> Void)?

    var body: some View {
        if loading {
            VStack {
                ProgressView()
                Text(loadingLabel)
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else if let error {
            VStack(alignment: .leading, spacing: 8) {
                Text("Couldn't load this: \(error)")
                    .font(.brandBody(14))
                    .foregroundStyle(Color.negative)
                if let onRetry {
                    Button("Try again", action: onRetry)
                        .font(.brandBody(14, weight: .medium))
                        .foregroundStyle(Color.negative)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.negative.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.negative.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal)
            .padding(.top, 20)
        }
    }
}
