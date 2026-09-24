//
//  PropCardView.swift
//  Chalk That NFL
//
//  Mirrors PropsPage.jsx's PropCard — player name (tappable through to
//  PlayerDetailView, same as web's Link to /players/:id), the market
//  line + O/U prices (or Yes/No prices for player_anytime_td), the
//  real recent-form context underneath, and a trailing badge: the
//  locked-in FinalResultBadge once the game is final, else the pregame
//  LeanBadge — same swap web's own PropCard does via gradeProp().
//
//  Deliberately NOT the web card's whole-card `pointer` styling on
//  every element — only the player's name pushes, matching the
//  existing GameRowView/BoardGameCardView precedent of not making team
//  abbreviations separately tappable either.
//
import SwiftUI

struct PropCardView: View {
    let prop: PropRow

    private var isAnytimeTd: Bool { prop.market == "player_anytime_td" }
    private var grade: PropGrade? { PropGradingLogic.grade(prop) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        NavigationLink(value: AgentsRoute.playerDetail(prop.player.playerId)) {
                            Text(prop.player.fullName)
                                .font(.brandBody(15, weight: .semibold))
                                .foregroundStyle(Color.ink)
                        }
                        Text(prop.player.position)
                            .font(.brandBody(11))
                            .foregroundStyle(Color.inkFaint)
                    }

                    Group {
                        if isAnytimeTd {
                            Text("Yes \(PropGradingLogic.formatPrice(prop.overPrice)) · No \(PropGradingLogic.formatPrice(prop.underPrice))")
                        } else {
                            Text("\(prop.line.map(PropGradingLogic.formatLine) ?? "—") \(prop.marketLabel) · O \(PropGradingLogic.formatPrice(prop.overPrice)) / U \(PropGradingLogic.formatPrice(prop.underPrice))")
                        }
                    }
                    .font(.brandBody(13))
                    .foregroundStyle(Color.inkDim)

                    if !isAnytimeTd, let recentAvg = prop.context.recentAvg {
                        Text("L5 avg \(String(format: "%.1f", recentAvg)) (\(String(prop.context.gamesPlayed)) gm)")
                            .font(.brandBody(11))
                            .foregroundStyle(Color.inkFaint)
                    }
                    if isAnytimeTd, let tdRate = prop.context.tdRate {
                        Text("TD in \(String(Int((tdRate * 100).rounded())))% of last \(String(prop.context.gamesPlayed)) games")
                            .font(.brandBody(11))
                            .foregroundStyle(Color.inkFaint)
                    }

                    if let reasoning = prop.reasoning {
                        Text(reasoning)
                            .font(.brandBody(11))
                            .italic()
                            .foregroundStyle(Color.inkFaint)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    if let grade {
                        FinalResultBadgeView(grade: grade)
                    } else {
                        LeanBadgeView(lean: prop.lean)
                    }
                    Text(prop.bookmaker == "draftkings" ? "DraftKings" : prop.bookmaker)
                        .font(.brandBody(10))
                        .foregroundStyle(Color.inkFaint)
                }
            }
        }
        .padding(12)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.line, lineWidth: 1)
        )
    }
}

/// Shared chip shape for both badges below. Web's own badges (LEAN_BADGE
/// and GRADE_VARIANT) share this same split: a real over/under/toss-up
/// result gets its own color at 12% opacity, but the neutral case
/// ("no read", or a final push/void) is a DIFFERENT shape entirely —
/// solid `bg-surface-2` with plain `text-ink-dim`, never that same
/// color tinted at 12%. Padding is applied before the background (not
/// after) so the tint/solid fill covers the full chip, not just the
/// tightly-sized text inside it.
private enum PropBadgeTone {
    case positive, negative, caution, neutral

    var foreground: Color {
        switch self {
        case .positive: return Color.positive
        case .negative: return Color.negative
        case .caution: return Color.caution
        case .neutral: return Color.inkDim
        }
    }

    var background: Color {
        switch self {
        case .neutral: return Color.surface2
        default: return foreground.opacity(0.12)
        }
    }
}

private struct PropBadgeChip: View {
    let label: String
    let tone: PropBadgeTone
    var showsCheck: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            if showsCheck { Text("✓") }
            Text(label)
        }
        .font(.brandBody(11, weight: .semibold))
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tone.background)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct LeanBadgeView: View {
    let lean: String?

    var body: some View {
        let resolved = PropLean(rawValue: lean ?? "")
        PropBadgeChip(label: resolved?.badgeLabel ?? "NO READ", tone: tone)
    }

    private var tone: PropBadgeTone {
        switch lean {
        case "over": return .positive
        case "under": return .negative
        case "toss_up": return .caution
        default: return .neutral
        }
    }
}

private struct FinalResultBadgeView: View {
    let grade: PropGrade

    var body: some View {
        PropBadgeChip(label: grade.label, tone: tone, showsCheck: grade.showsCheck)
    }

    private var tone: PropBadgeTone {
        switch grade.tone {
        case .positive: return .positive
        case .negative: return .negative
        case .neutral: return .neutral
        }
    }
}
